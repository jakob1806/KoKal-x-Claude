// Reichert bestehende Events nachträglich mit Komponisten/Werken/Mitwirkenden
// an: liest title+description_de, schickt sie an die Anthropic API (dasselbe
// forced-tool-call-Muster wie extract-event-from-url/llm.ts), matcht die
// erkannten Namen gegen persons/ensembles/works (case-insensitive exact
// match — bewusst kein Fuzzy-Matching, um keine unterschiedlichen Personen
// versehentlich zusammenzulegen), legt fehlende Einträge an und verknüpft
// über event_works / event_participants.
//
// Aufruf: POST { limit?: number } — verarbeitet bis zu `limit` (Default 20)
// scheduled Events, die noch keine event_works/event_participants-Zeile
// haben. Mehrfacher Aufruf nötig, um alle 238 Events abzudecken (Edge
// Function Zeitlimit).
//
// Braucht ANTHROPIC_API_KEY als Supabase-Secret (siehe
// extract-event-from-url/llm.ts für Setup).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001";

const ENRICH_TOOL = {
  name: "extract_references",
  description: "Aus Titel+Beschreibung eines Konzerts erkannte Komponisten, Werke und Mitwirkende.",
  input_schema: {
    type: "object",
    properties: {
      works: {
        type: "array",
        description:
          "Nur konkrete, benannte Werke (z. B. 'Symphonie Nr. 5', 'Matthäus-Passion'). " +
          "KEINEN Eintrag erzeugen, wenn nur ein Komponisten-Nachname ohne erkennbares " +
          "spezifisches Werk im Text steht — dann leer lassen statt zu raten.",
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            composerName: {
              type: ["string", "null"],
              description: "Voller Name des Komponisten, falls erkennbar (z. B. 'Johannes Brahms').",
            },
          },
          required: ["title"],
        },
      },
      participants: {
        type: "array",
        description:
          "Auftretende Personen/Ensembles. NIEMALS Ticketing-Agenturen, Konzertdirektionen, " +
          "Veranstalter-GmbHs oder Spielstätten hier eintragen (z. B. 'MünchenMusik GmbH & Co. KG', " +
          "'Bell' Arte Konzertdirektion' sind KEINE Mitwirkenden) — nur echte Musiker/Ensembles.",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            type: { type: "string", enum: ["person", "ensemble"] },
            role: {
              type: ["string", "null"],
              enum: ["komponist", "dirigent", "solist", "chorleiter", "moderator", null],
              description: "Nur setzen, wenn im Text erkennbar; sonst null (z. B. ein einfach mitspielendes Orchester).",
            },
            ensembleType: {
              type: ["string", "null"],
              enum: ["chor", "orchester", "kammerensemble", "big_band", "sonstiges", null],
              description: "Nur bei type=ensemble relevant.",
            },
            instrument: { type: ["string", "null"] },
          },
          required: ["name", "type"],
        },
      },
    },
    required: ["works", "participants"],
  },
};

interface EventRow {
  id: string;
  title: string;
  description_de: string | null;
}

// deno-lint-ignore no-explicit-any
function isRecord(v: unknown): v is Record<string, any> {
  return v != null && typeof v === "object";
}

async function extractReferences(
  apiKey: string,
  title: string,
  description: string | null,
): Promise<{ works: Array<{ title: string; composerName: string | null }>; participants: Array<{ name: string; type: string; role: string | null; ensembleType: string | null; instrument: string | null }> } | null> {
  const text = `Titel: ${title}${description ? `\nBeschreibung: ${description}` : ""}`;

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
        max_tokens: 1024,
        system:
          "Du extrahierst Komponisten, Werke und Mitwirkende aus Titel/Beschreibung eines " +
          "klassischen Konzerts. Sei konservativ: lieber ein leeres Array als geraten.",
        messages: [{ role: "user", content: text }],
        tools: [ENRICH_TOOL],
        tool_choice: { type: "tool", name: "extract_references" },
      }),
    });
  } catch {
    return null;
  }
  if (!res.ok) return null;

  const data = await res.json();
  const blocks = Array.isArray(data.content) ? data.content : [];
  const toolUse = blocks.find((b: unknown) => isRecord(b) && b.type === "tool_use" && b.name === "extract_references");
  if (!toolUse || !isRecord(toolUse.input)) return null;

  const works = Array.isArray(toolUse.input.works) ? toolUse.input.works : [];
  const participants = Array.isArray(toolUse.input.participants) ? toolUse.input.participants : [];
  return { works, participants };
}

function slugify(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

Deno.serve(async (req) => {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY nicht gesetzt" }), { status: 500 });
  }

  let body: { limit?: unknown };
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const limit = typeof body.limit === "number" && body.limit > 0 ? Math.min(body.limit, 50) : 20;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  // PostgREST kennt keine Subqueries in .not(...,'in',...) — daher die
  // bereits verknüpften event_ids separat holen und die Differenz in JS
  // bilden statt sie der DB als (fehlerhaften) Literal-Liste zu übergeben.
  const { data: allScheduled, error: fetchError } = await supabase
    .from("events")
    .select("id, title, description_de")
    .eq("status", "scheduled")
    .order("id")
    .returns<EventRow[]>();

  if (fetchError) {
    return new Response(JSON.stringify({ error: fetchError.message }), { status: 500 });
  }

  const [{ data: linkedWorks }, { data: linkedParticipants }] = await Promise.all([
    supabase.from("event_works").select("event_id"),
    supabase.from("event_participants").select("event_id"),
  ]);
  const linkedIds = new Set<string>([
    ...(linkedWorks ?? []).map((r: { event_id: string }) => r.event_id),
    ...(linkedParticipants ?? []).map((r: { event_id: string }) => r.event_id),
  ]);

  const candidates = (allScheduled ?? []).filter((e) => !linkedIds.has(e.id)).slice(0, limit);
  if (candidates.length === 0) {
    return new Response(JSON.stringify({ processed: 0, message: "Keine Events ohne Verknüpfung mehr übrig." }));
  }

  let worksCreated = 0;
  let personsCreated = 0;
  let ensemblesCreated = 0;
  let linksCreated = 0;
  const errors: string[] = [];

  for (const event of candidates) {
    const extracted = await extractReferences(apiKey, event.title, event.description_de);
    if (!extracted) {
      errors.push(`"${event.title}": Anthropic-Aufruf fehlgeschlagen`);
      continue;
    }

    // Cache innerhalb dieses Laufs, um nicht pro Event erneut nachzuschlagen,
    // wenn derselbe Name (z. B. ein Hausorchester) mehrfach vorkommt.
    const personCache = new Map<string, string>();
    const ensembleCache = new Map<string, string>();

    async function getOrCreatePerson(name: string): Promise<string> {
      const key = name.toLowerCase();
      if (personCache.has(key)) return personCache.get(key)!;
      const { data: existing } = await supabase
        .from("persons")
        .select("id")
        .ilike("full_name", name)
        .maybeSingle();
      if (existing) {
        personCache.set(key, existing.id);
        return existing.id;
      }
      const { data: created, error } = await supabase
        .from("persons")
        .insert({ full_name: name, slug: slugify(name) })
        .select("id")
        .single();
      if (error) throw new Error(`persons insert "${name}": ${error.message}`);
      personsCreated++;
      personCache.set(key, created.id);
      return created.id;
    }

    async function getOrCreateEnsemble(name: string, type: string | null): Promise<string> {
      const key = name.toLowerCase();
      if (ensembleCache.has(key)) return ensembleCache.get(key)!;
      const { data: existing } = await supabase
        .from("ensembles")
        .select("id")
        .ilike("name", name)
        .maybeSingle();
      if (existing) {
        ensembleCache.set(key, existing.id);
        return existing.id;
      }
      const { data: created, error } = await supabase
        .from("ensembles")
        .insert({ name, slug: slugify(name), type: type ?? "sonstiges" })
        .select("id")
        .single();
      if (error) throw new Error(`ensembles insert "${name}": ${error.message}`);
      ensemblesCreated++;
      ensembleCache.set(key, created.id);
      return created.id;
    }

    try {
      for (const [i, w] of extracted.works.entries()) {
        if (!w.title?.trim()) continue;
        const composerId = w.composerName?.trim() ? await getOrCreatePerson(w.composerName.trim()) : null;

        const { data: existingWork } = await supabase
          .from("works")
          .select("id")
          .ilike("title", w.title.trim())
          .maybeSingle();
        let workId: string;
        if (existingWork) {
          workId = existingWork.id;
        } else {
          const { data: createdWork, error } = await supabase
            .from("works")
            .insert({ title: w.title.trim(), composer_id: composerId })
            .select("id")
            .single();
          if (error) throw new Error(`works insert "${w.title}": ${error.message}`);
          worksCreated++;
          workId = createdWork.id;
        }

        // PK ist (event_id, work_id, position) — kein simpler (event_id,
        // work_id)-Unique-Constraint, also erst prüfen statt upsert.
        const { data: existingLink } = await supabase
          .from("event_works")
          .select("event_id")
          .eq("event_id", event.id)
          .eq("work_id", workId)
          .maybeSingle();
        if (!existingLink) {
          const { error: linkError } = await supabase
            .from("event_works")
            .insert({ event_id: event.id, work_id: workId, position: i });
          if (linkError) throw new Error(`event_works link: ${linkError.message}`);
          linksCreated++;
        }
      }

      for (const [i, p] of extracted.participants.entries()) {
        if (!p.name?.trim()) continue;
        const isEnsemble = p.type === "ensemble";
        const entityId = isEnsemble
          ? await getOrCreateEnsemble(p.name.trim(), p.ensembleType ?? null)
          : await getOrCreatePerson(p.name.trim());

        const { error: linkError } = await supabase
          .from("event_participants")
          .insert({
            event_id: event.id,
            person_id: isEnsemble ? null : entityId,
            ensemble_id: isEnsemble ? entityId : null,
            role: p.role ?? null,
            display_order: i,
          });
        if (linkError) throw new Error(`event_participants link "${p.name}": ${linkError.message}`);
        linksCreated++;
      }
    } catch (err) {
      errors.push(`"${event.title}": ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  return new Response(
    JSON.stringify({
      processed: candidates.length,
      worksCreated,
      personsCreated,
      ensemblesCreated,
      linksCreated,
      errorCount: errors.length,
      errors: errors.slice(0, 10),
    }),
  );
});
