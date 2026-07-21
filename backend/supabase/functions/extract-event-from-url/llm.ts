// KI-Fallback für extract-event-from-url: wenn Schema.org keine Events
// liefert, schickt dies den sichtbaren Seitentext an die Gemini API und
// bittet um strukturierte Event-Extraktion. Eine Seite kann EIN einzelnes
// Konzert zeigen oder ein GANZES Programm mit vielen Terminen — beides
// landet als jeweils ein Eintrag pro echtem Termin im selben events-Array,
// das Function-Schema unten unterscheidet nicht zwischen beiden Fällen.
//
// Braucht GEMINI_API_KEY als Supabase-Secret (siehe _shared/gemini.ts) —
// ohne den Key liefert diese Funktion einen klaren Fehler statt eines still
// leeren Ergebnisses.

import { callGeminiFunction, type GeminiFunctionDeclaration } from "../_shared/gemini.ts";
import type { RawEvent } from "../ingest-source/types.ts";

const MAX_TEXT_CHARS = 15000; // grobe Kosten-/Token-Begrenzung pro Aufruf

const EVENT_EXTRACTION_FUNCTION: GeminiFunctionDeclaration = {
  name: "extract_events",
  description: "Aus dem Seitentext erkannte Konzert-/Veranstaltungsdaten.",
  parameters: {
    type: "OBJECT",
    properties: {
      events: {
        type: "ARRAY",
        description:
          "Ein Eintrag pro erkanntem Konzert/Termin. Leeres Array, wenn keine echte Veranstaltung im Text erkennbar ist — kein Datum erfinden.",
        items: {
          type: "OBJECT",
          properties: {
            title: { type: "STRING" },
            description: {
              type: "STRING",
              nullable: true,
              description: "Programm, Werke, Mitwirkende — falls im Text vorhanden.",
            },
            startDateTime: {
              type: "STRING",
              description:
                "ISO 8601 mit Zeitzonen-Offset, z.B. 2026-08-15T19:30:00+02:00. Fehlt im Text das Jahr, aus dem heutigen Datum ableiten (Veranstaltungsseiten zeigen kommende, nicht vergangene Termine).",
            },
            venueName: { type: "STRING", nullable: true },
            venueAddress: { type: "STRING", nullable: true },
            priceMin: { type: "NUMBER", nullable: true },
            priceMax: { type: "NUMBER", nullable: true },
            isFree: { type: "BOOLEAN", nullable: true },
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
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return {
      events: [],
      errors: [
        "GEMINI_API_KEY ist nicht als Supabase-Secret gesetzt — KI-Fallback nicht verfügbar " +
          "(Schema.org-Extraktion hat für diese Seite keine Events gefunden).",
      ],
    };
  }

  const truncated = pageText.slice(0, MAX_TEXT_CHARS);
  if (!truncated.trim()) {
    return { events: [], errors: ["Seitentext war leer — nichts zu extrahieren."] };
  }

  const args = await callGeminiFunction(
    apiKey,
    `Heutiges Datum: ${todayIso}. Du extrahierst Konzert-/Veranstaltungsdaten aus dem Text ` +
      `einer Webseite. Ignoriere Navigation, Cookie-Hinweise, Werbung und sonstige nicht ` +
      `Event-bezogene Inhalte.`,
    `Seiten-URL: ${sourceUrl}\n\nSeitentext:\n${truncated}`,
    EVENT_EXTRACTION_FUNCTION,
  );

  if (!args) {
    return { events: [], errors: ["Gemini-Aufruf fehlgeschlagen oder lieferte keinen extract_events-Aufruf."] };
  }

  const rawEvents = Array.isArray(args.events) ? args.events : [];
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
