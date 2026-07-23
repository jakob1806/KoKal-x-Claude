// Reichert bestehende Events nachträglich mit Komponisten/Werken/Mitwirkenden
// an: liest title+description_de, schickt sie an die Gemini API (dasselbe
// forced-function-call-Muster wie extract-event-from-url/llm.ts), matcht die
// erkannten Namen gegen persons/ensembles/works (case-insensitive exact
// match — bewusst kein Fuzzy-Matching, um keine unterschiedlichen Personen
// versehentlich zusammenzulegen) und verknüpft über event_works /
// event_participants. Unbekannte Personen/Ensembles werden NICHT mehr
// direkt angelegt (das passierte hier früher ungeprüft) — sie landen als
// entity_candidates zur redaktionellen Freigabe
// (20260818000004_entity_candidates.sql); die event_participants-
// Verknüpfung für so einen Act folgt erst nach Freigabe bei einem
// erneuten Lauf. Komponisten von Werken bleiben davon unberührt: ein noch
// nicht bestätigter Komponistenname führt nur zu einem Werk ohne
// composer_id (composer_id ist ohnehin nullable), keine Sonderbehandlung
// nötig.
//
// Beim Anlegen eines neuen Kandidaten wird zusätzlich per Tavily (siehe
// _shared/tavily.ts) nach dem Namen gesucht und der Treffer per LLM zu
// einer kurzen Einordnung (Bio-Snippet, Website) zusammengefasst — landet
// in discovery_context.tavily und gibt dem Redakteur im Review mehr als
// nur den nackten Namen. Rein additiv: fehlt TAVILY_API_KEY oder schlägt
// die Suche fehl, wird der Kandidat trotzdem ganz normal ohne Anreicherung
// angelegt.
//
// Aufruf: POST { limit?: number } — verarbeitet bis zu `limit` (Default 20)
// scheduled Events, die noch keine event_works/event_participants-Zeile
// haben. Mehrfacher Aufruf nötig, um alle 238 Events abzudecken (Edge
// Function Zeitlimit).
//
// Nutzt die AI-Provider-Fallback-Kette aus _shared/ai/router.ts statt eines
// fest hinterlegten einzelnen Providers — siehe dort für die Begründung.
// Braucht mindestens eines der dort verdrahteten Provider-Secrets
// (CEREBRAS_API_KEY, NVIDIA_API_KEY, GEMINI_API_KEY) und optional
// TAVILY_API_KEY (siehe _shared/tavily.ts) für die Kandidaten-Anreicherung.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callAiFunction, hasAnyAiProviderConfigured, type AiFunctionDeclaration } from "../_shared/ai/router.ts";
import { searchTavily } from "../_shared/tavily.ts";
import { logSystemAction } from "../_shared/systemLog.ts";

const SUMMARIZE_ARTIST_FUNCTION: AiFunctionDeclaration = {
  name: "summarize_artist",
  description:
    "Fasst Websuche-Treffer zu einem/einer klassischen Musiker*in/Ensemble zu einer kurzen " +
    "Einordnung für die redaktionelle Prüfung zusammen.",
  parameters: {
    type: "object",
    properties: {
      bioSnippet: {
        type: "string",
        description:
          "1-2 Sätze Einordnung (z. B. Instrument/Stimmfach, bekannt für, Orchester-Zugehörigkeit), " +
          "nur wenn die Treffer erkennbar dieselbe Person/dasselbe Ensemble betreffen. Sonst leerer String.",
      },
      websiteUrl: {
        type: "string",
        description: "Offizielle Website/Künstlerprofil-URL, falls unter den Treffern erkennbar, sonst leerer String.",
      },
      confident: {
        type: "boolean",
        description:
          "true nur, wenn die Treffer klar zu einem/einer klassischen Musiker*in/Ensemble mit diesem Namen " +
          "passen. false bei Namensvettern, Unklarheit oder komplett fehlendem Bezug zu klassischer Musik.",
      },
    },
    required: ["confident"],
  },
};

/** Websuche + LLM-Zusammenfassung für einen neu entdeckten Kandidatennamen.
 * Rein additive Anreicherung von discovery_context — schlägt die Suche oder
 * Zusammenfassung fehl (kein TAVILY_API_KEY, Netzwerkfehler, kein Treffer),
 * wird der Kandidat trotzdem ganz normal ohne Anreicherung angelegt. */
async function enrichCandidateContext(
  entityType: "person" | "ensemble",
  name: string,
): Promise<{ bioSnippet: string | null; websiteUrl: string | null } | null> {
  const tavilyApiKey = Deno.env.get("TAVILY_API_KEY");
  if (!tavilyApiKey) return null;

  const kind = entityType === "person" ? "Musiker" : "Ensemble";
  const results = await searchTavily(tavilyApiKey, `${name} ${kind} klassische Musik`);
  if (!results || results.length === 0) return null;

  const searchText = results.map((r) => `${r.title}\n${r.content}`).join("\n\n");
  const response = await callAiFunction(
    "Du ordnest Websuche-Treffer zu einem möglichen klassischen Musiker/Ensemble ein. " +
      "Sei konservativ: bei Unklarheit oder Namensvettern lieber confident=false und leere Felder.",
    `Gesuchter Name: "${name}"\n\nTreffer:\n${searchText}`,
    SUMMARIZE_ARTIST_FUNCTION,
  );
  const args = response?.args;
  if (!args || args.confident !== true) return null;

  return {
    bioSnippet: typeof args.bioSnippet === "string" && args.bioSnippet.trim() ? args.bioSnippet.trim() : null,
    websiteUrl: typeof args.websiteUrl === "string" && args.websiteUrl.trim() ? args.websiteUrl.trim() : null,
  };
}

const ENRICH_FUNCTION: AiFunctionDeclaration = {
  name: "extract_references",
  description: "Aus Titel+Beschreibung eines Konzerts erkannte Komponisten, Werke und Mitwirkende.",
  parameters: {
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
              type: "string",
              description: "Voller Name des Komponisten, falls erkennbar (z. B. 'Johannes Brahms'), sonst weglassen.",
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
              type: "string",
              enum: ["komponist", "dirigent", "solist", "chorleiter", "moderator"],
              description: "Nur setzen, wenn im Text erkennbar; sonst weglassen (z. B. ein einfach mitspielendes Orchester).",
            },
            ensembleType: {
              type: "string",
              enum: ["chor", "orchester", "kammerensemble", "big_band", "sonstiges"],
              description: "Nur bei type=ensemble relevant, sonst weglassen.",
            },
            instrument: { type: "string", description: "Falls im Text erkennbar, sonst weglassen." },
          },
          required: ["name", "type"],
        },
      },
      tags: {
        type: "array",
        description:
          "1-5 kurze, wiederverwendbare Schlagworte auf Deutsch (z. B. 'Barock', 'Familienkonzert', 'Orgel', " +
          "'A-cappella', 'Uraufführung'). KEINE Komponisten-/Werktitel-Wiederholungen aus works/participants, " +
          "keine Venue-/Datumsangaben — nur Stichworte, die ein Nutzer als Filter/Suchbegriff nutzen würde. " +
          "Leeres Array, wenn nichts Spezifisches erkennbar ist.",
        items: { type: "string" },
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

async function extractReferences(
  title: string,
  description: string | null,
): Promise<{ works: Array<{ title: string; composerName: string | null }>; participants: Array<{ name: string; type: string; role: string | null; ensembleType: string | null; instrument: string | null }>; tags: string[] } | null> {
  const text = `Titel: ${title}${description ? `\nBeschreibung: ${description}` : ""}`;

  const response = await callAiFunction(
    "Du extrahierst Komponisten, Werke und Mitwirkende aus Titel/Beschreibung eines " +
      "klassischen Konzerts. Sei konservativ: lieber ein leeres Array als geraten.",
    text,
    ENRICH_FUNCTION,
  );
  const args = response?.args;
  if (!args) return null;

  const works = Array.isArray(args.works) ? args.works : [];
  const participants = Array.isArray(args.participants) ? args.participants : [];
  const tags = Array.isArray(args.tags) ? args.tags.filter((t: unknown) => typeof t === "string" && t.trim()) : [];
  return { works, participants, tags };
}

Deno.serve(async (req) => {
  if (!hasAnyAiProviderConfigured()) {
    return new Response(
      JSON.stringify({ error: "Kein AI-Provider-Secret gesetzt (CEREBRAS_API_KEY, NVIDIA_API_KEY oder GEMINI_API_KEY)" }),
      { status: 500 },
    );
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

  // Auswahl über references_checked_at statt "hat noch keine
  // event_works/event_participants-Zeile" — ein Event mit ausschließlich
  // unbekannten Mitwirkenden (→ landen als entity_candidates, keine
  // Verknüpfung) bekäme sonst NIE eine solche Zeile und würde bei jedem Lauf
  // erneut ausgewählt, was den gesamten Batch-Fortschritt blockiert (siehe
  // 20260722000001_events_references_checked_at.sql).
  const { data: candidates, error: fetchError } = await supabase
    .from("events")
    .select("id, title, description_de")
    .eq("status", "scheduled")
    .is("references_checked_at", null)
    .order("id")
    .limit(limit)
    .returns<EventRow[]>();

  if (fetchError) {
    return new Response(JSON.stringify({ error: fetchError.message }), { status: 500 });
  }
  if (!candidates || candidates.length === 0) {
    return new Response(JSON.stringify({ processed: 0, message: "Keine ungeprüften Events mehr übrig." }));
  }

  let worksCreated = 0;
  let personsFlagged = 0;
  let ensemblesFlagged = 0;
  let linksCreated = 0;
  const errors: string[] = [];

  for (const event of candidates) {
    const extracted = await extractReferences(event.title, event.description_de);
    if (!extracted) {
      errors.push(`"${event.title}": AI-Aufruf fehlgeschlagen (alle Provider)`);
      continue; // kein Mark — bei transientem Providerfehler soll ein späterer Lauf es erneut versuchen
    }

    // Als geprüft markieren, SOBALD die Extraktion selbst geklappt hat —
    // unabhängig davon, ob am Ende Links entstehen (unbekannte Mitwirkende
    // landen nur als entity_candidates) oder ein einzelner DB-Insert weiter
    // unten fehlschlägt. Sonst würde genau dieses Event beim nächsten Lauf
    // wieder ausgewählt und der Batch käme nie über die ersten paar Events
    // hinaus (siehe Migrationskommentar).
    await supabase.from("events").update({ references_checked_at: new Date().toISOString() }).eq("id", event.id);

    // Cache innerhalb dieses Laufs, um nicht pro Event erneut nachzuschlagen,
    // wenn derselbe Name (z. B. ein Hausorchester) mehrfach vorkommt. `null`
    // heißt "unbekannt, bereits als entity_candidate geflaggt" — auch das
    // wird gecacht, um nicht zweimal denselben Kandidaten anzulegen.
    const personCache = new Map<string, string | null>();
    const ensembleCache = new Map<string, string | null>();

    // Unbekannte Namen werden NICHT mehr direkt in persons/ensembles
    // angelegt (das hat vorher ohne jede Prüfung neue Stammdaten erzeugt) —
    // stattdessen landen sie als entity_candidates zur redaktionellen
    // Freigabe (siehe 20260818000004_entity_candidates.sql), konsistent mit
    // der Discovery-Pipeline für externe Acts. Rückgabe null heißt "noch
    // keine ID verfügbar" — der Aufrufer verknüpft dann (noch) nichts.
    async function flagEntityCandidate(
      entityType: "person" | "ensemble",
      name: string,
      possibleMatch?: { id: string; name: string; similarity: number },
    ): Promise<void> {
      const { data: existingCandidate } = await supabase
        .from("entity_candidates")
        .select("id")
        .eq("entity_type", entityType)
        .ilike("name", name)
        .eq("status", "pending")
        .maybeSingle();
      if (existingCandidate) return;

      const enrichment = await enrichCandidateContext(entityType, name);

      const { error } = await supabase.from("entity_candidates").insert({
        entity_type: entityType,
        name,
        discovery_context: {
          source: "enrich-event-references",
          event_id: event.id,
          ...(enrichment ? { tavily: enrichment } : {}),
          ...(possibleMatch ? { possible_match: possibleMatch } : {}),
        },
        suggested_event_title: event.title,
      });
      if (error) console.error(`flagEntityCandidate "${name}": ${error.message}`);
    }

    // Schwellwerte für Fuzzy-Matching (Architektur-Dokument Abschnitt 2.3):
    // >= AUTO-Schwelle wird automatisch verknüpft (nur geloggt, kein Review
    // nötig — Tippfehler/Kleinschreibungsvarianten sind hier eindeutig).
    // Zwischen FLAG- und AUTO-Schwelle wird NICHT automatisch verknüpft,
    // sondern nur als Hinweis (`possible_match`) an den entity_candidate
    // angehängt — zwei verschiedene Personen desselben/ähnlichen Namens sind
    // real (z.B. mehrere "Michael Schmidt"), das entscheidet ein Redakteur.
    const FUZZY_AUTO_THRESHOLD = 0.85;
    const FUZZY_FLAG_THRESHOLD = 0.5;

    async function getOrCreatePerson(name: string): Promise<string | null> {
      const key = name.toLowerCase();
      if (personCache.has(key)) return personCache.get(key) ?? null;
      const { data: existing } = await supabase
        .from("persons")
        .select("id")
        .ilike("full_name", name)
        .maybeSingle();
      if (existing) {
        personCache.set(key, existing.id);
        return existing.id;
      }

      const { data: fuzzyMatches } = await supabase.rpc("find_matching_person", { p_name: name });
      const bestMatch = fuzzyMatches?.[0] as { id: string; full_name: string; similarity: number } | undefined;
      if (bestMatch && bestMatch.similarity >= FUZZY_AUTO_THRESHOLD) {
        await logSystemAction(supabase, "person", bestMatch.id, "fuzzy_auto_link", {
          matched_name: name,
          linked_to: bestMatch.full_name,
          similarity: bestMatch.similarity,
          event_id: event.id,
        });
        personCache.set(key, bestMatch.id);
        return bestMatch.id;
      }

      await flagEntityCandidate(
        "person",
        name,
        bestMatch && bestMatch.similarity >= FUZZY_FLAG_THRESHOLD
          ? { id: bestMatch.id, name: bestMatch.full_name, similarity: bestMatch.similarity }
          : undefined,
      );
      personsFlagged++;
      personCache.set(key, null);
      return null;
    }

    async function getOrCreateEnsemble(name: string, _type: string | null): Promise<string | null> {
      const key = name.toLowerCase();
      if (ensembleCache.has(key)) return ensembleCache.get(key) ?? null;
      const { data: existing } = await supabase
        .from("ensembles")
        .select("id")
        .ilike("name", name)
        .maybeSingle();
      if (existing) {
        ensembleCache.set(key, existing.id);
        return existing.id;
      }

      const { data: fuzzyMatches } = await supabase.rpc("find_matching_ensemble", { p_name: name });
      const bestMatch = fuzzyMatches?.[0] as { id: string; name: string; similarity: number } | undefined;
      if (bestMatch && bestMatch.similarity >= FUZZY_AUTO_THRESHOLD) {
        await logSystemAction(supabase, "ensemble", bestMatch.id, "fuzzy_auto_link", {
          matched_name: name,
          linked_to: bestMatch.name,
          similarity: bestMatch.similarity,
          event_id: event.id,
        });
        ensembleCache.set(key, bestMatch.id);
        return bestMatch.id;
      }

      await flagEntityCandidate(
        "ensemble",
        name,
        bestMatch && bestMatch.similarity >= FUZZY_FLAG_THRESHOLD
          ? { id: bestMatch.id, name: bestMatch.name, similarity: bestMatch.similarity }
          : undefined,
      );
      ensemblesFlagged++;
      ensembleCache.set(key, null);
      return null;
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

        // Unbekannter Act — als entity_candidate geflaggt, aber noch keine
        // ID vorhanden. Verknüpfung unterbleibt bis zur Freigabe (siehe
        // getOrCreatePerson/getOrCreateEnsemble oben); kein Fehler.
        if (entityId === null) continue;

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

      for (const tagName of extracted.tags) {
        const trimmed = tagName.trim();
        if (!trimmed) continue;

        const { data: existingTag } = await supabase
          .from("tags")
          .select("id")
          .ilike("name", trimmed)
          .maybeSingle();

        let tagId: string;
        if (existingTag) {
          tagId = existingTag.id;
        } else {
          const { data: createdTag, error: tagInsertError } = await supabase
            .from("tags")
            .insert({ name: trimmed, is_ai_generated: true })
            .select("id")
            .single();
          if (tagInsertError) {
            // Race mit einem parallelen Lauf, der denselben Tag gerade
            // angelegt hat (tags.name ist unique) — kein echter Fehler,
            // einfach überspringen statt den ganzen Event-Write abzubrechen.
            console.error(`tags insert "${trimmed}": ${tagInsertError.message}`);
            continue;
          }
          tagId = createdTag.id;
        }

        const { error: eventTagError } = await supabase
          .from("event_tags")
          .upsert({ event_id: event.id, tag_id: tagId }, { onConflict: "event_id,tag_id" });
        if (eventTagError) console.error(`event_tags link "${trimmed}": ${eventTagError.message}`);
      }
    } catch (err) {
      errors.push(`"${event.title}": ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  return new Response(
    JSON.stringify({
      processed: candidates.length,
      worksCreated,
      personsFlagged,
      ensemblesFlagged,
      linksCreated,
      errorCount: errors.length,
      errors: errors.slice(0, 10),
    }),
  );
});
