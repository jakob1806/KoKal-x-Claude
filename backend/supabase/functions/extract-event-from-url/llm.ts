// KI-Fallback für extract-event-from-url: wenn Schema.org keine Events
// liefert, schickt dies den sichtbaren Seitentext an die Anthropic API und
// bittet um strukturierte Event-Extraktion. Eine Seite kann EIN einzelnes
// Konzert zeigen oder ein GANZES Programm mit vielen Terminen — beides
// landet als jeweils ein Eintrag pro echtem Termin im selben events-Array,
// das Tool-Schema unten unterscheidet nicht zwischen beiden Fällen.
//
// Braucht ANTHROPIC_API_KEY als Supabase-Secret (`supabase secrets set
// ANTHROPIC_API_KEY=... --project-ref <ref>` oder im Dashboard unter Edge
// Functions > Secrets) — ohne den Key liefert diese Funktion einen klaren
// Fehler statt eines still leeren Ergebnisses.

import type { RawEvent } from "../ingest-source/types.ts";

const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001";
const MAX_TEXT_CHARS = 15000; // grobe Kosten-/Token-Begrenzung pro Aufruf

const EVENT_EXTRACTION_TOOL = {
  name: "extract_events",
  description: "Aus dem Seitentext erkannte Konzert-/Veranstaltungsdaten.",
  input_schema: {
    type: "object",
    properties: {
      events: {
        type: "array",
        description:
          "Ein Eintrag pro erkanntem Konzert/Termin. Leeres Array, wenn keine echte Veranstaltung im Text erkennbar ist — kein Datum erfinden.",
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            description: {
              type: ["string", "null"],
              description: "Programm, Werke, Mitwirkende — falls im Text vorhanden.",
            },
            startDateTime: {
              type: "string",
              description:
                "ISO 8601 mit Zeitzonen-Offset, z.B. 2026-08-15T19:30:00+02:00. Fehlt im Text das Jahr, aus dem heutigen Datum ableiten (Veranstaltungsseiten zeigen kommende, nicht vergangene Termine).",
            },
            venueName: { type: ["string", "null"] },
            venueAddress: { type: ["string", "null"] },
            priceMin: { type: ["number", "null"] },
            priceMax: { type: ["number", "null"] },
            isFree: { type: ["boolean", "null"] },
          },
          required: ["title", "startDateTime"],
        },
      },
    },
    required: ["events"],
  },
};

// deno-lint-ignore no-explicit-any
function isRecord(v: unknown): v is Record<string, any> {
  return v != null && typeof v === "object";
}

export async function extractEventsWithLlm(
  pageText: string,
  sourceUrl: string,
  todayIso: string,
): Promise<{ events: RawEvent[]; errors: string[] }> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return {
      events: [],
      errors: [
        "ANTHROPIC_API_KEY ist nicht als Supabase-Secret gesetzt — KI-Fallback nicht verfügbar " +
          "(Schema.org-Extraktion hat für diese Seite keine Events gefunden).",
      ],
    };
  }

  const truncated = pageText.slice(0, MAX_TEXT_CHARS);
  if (!truncated.trim()) {
    return { events: [], errors: ["Seitentext war leer — nichts zu extrahieren."] };
  }

  let res: Response;
  try {
    res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: 4096,
        system:
          `Heutiges Datum: ${todayIso}. Du extrahierst Konzert-/Veranstaltungsdaten aus dem Text ` +
          `einer Webseite. Ignoriere Navigation, Cookie-Hinweise, Werbung und sonstige nicht ` +
          `Event-bezogene Inhalte.`,
        messages: [
          { role: "user", content: `Seiten-URL: ${sourceUrl}\n\nSeitentext:\n${truncated}` },
        ],
        tools: [EVENT_EXTRACTION_TOOL],
        tool_choice: { type: "tool", name: "extract_events" },
      }),
    });
  } catch (err) {
    return { events: [], errors: [`Anthropic API nicht erreichbar: ${err instanceof Error ? err.message : String(err)}`] };
  }

  if (!res.ok) {
    const body = await res.text();
    return { events: [], errors: [`Anthropic API antwortete mit ${res.status}: ${body.slice(0, 500)}`] };
  }

  const data = await res.json();
  const blocks = Array.isArray(data.content) ? data.content : [];
  const toolUse = blocks.find((b: unknown) => isRecord(b) && b.type === "tool_use" && b.name === "extract_events");
  if (!toolUse) {
    return { events: [], errors: ["Anthropic-Antwort enthielt keinen extract_events-Block."] };
  }

  const rawEvents = Array.isArray(toolUse.input?.events) ? toolUse.input.events : [];
  const errors: string[] = [];
  const events: RawEvent[] = [];

  for (const e of rawEvents) {
    if (!isRecord(e) || typeof e.title !== "string" || !e.title.trim() || typeof e.startDateTime !== "string") {
      errors.push(`Übersprungen: fehlender Titel oder Startzeit (${JSON.stringify(e).slice(0, 200)})`);
      continue;
    }
    const parsedDate = new Date(e.startDateTime);
    if (isNaN(parsedDate.getTime())) {
      errors.push(`"${e.title}": ungültiges Datum "${e.startDateTime}"`);
      continue;
    }
    events.push({
      // Kein externalId: dieselbe URL kann mehrere Events liefern (ganzes
      // Programm), ein pro-Seite geteilter externalId würde beim erneuten
      // Einfügen derselben URL zu einem Mehrdeutigkeits-Konflikt in der
      // exakten (source_id, external_id)-Suche in write.ts führen. Erneutes
      // Einfügen läuft stattdessen über den ohnehin vorhandenen
      // Fuzzy-Match (Titel+Venue+Zeit).
      externalId: null,
      title: e.title.trim(),
      description: typeof e.description === "string" ? (e.description.trim() || null) : null,
      startDateTime: parsedDate.toISOString(),
      endDateTime: null,
      venueName: typeof e.venueName === "string" ? (e.venueName.trim() || null) : null,
      venueAddress: typeof e.venueAddress === "string" ? (e.venueAddress.trim() || null) : null,
      url: sourceUrl,
      imageUrl: null,
      priceMin: typeof e.priceMin === "number" ? e.priceMin : null,
      priceMax: typeof e.priceMax === "number" ? e.priceMax : null,
      isFree: typeof e.isFree === "boolean" ? e.isFree : null,
    });
  }

  return { events, errors };
}
