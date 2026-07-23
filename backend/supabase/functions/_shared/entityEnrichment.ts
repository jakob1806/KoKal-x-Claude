// Gemeinsamer Baustein: Websuche (Tavily) + LLM-Einordnung für einen
// vermeintlichen klassischen Musiker/ein Ensemble — genutzt sowohl beim
// erstmaligen Anlegen eines entity_candidate (enrich-event-references) als
// auch beim nachträglichen Batch-Review bereits wartender Kandidaten
// (resolve-entity-candidates). confident=true ist die Voraussetzung dafür,
// dass eine KI-Entscheidung den Kandidaten automatisch auflösen darf statt
// ihn liegen zu lassen — siehe beide Aufrufer für die jeweilige Verwendung.
import { callAiFunction, type AiFunctionDeclaration } from "./ai/router.ts";
import { searchTavily } from "./tavily.ts";

export interface EntityEnrichment {
  bioSnippet: string | null;
  websiteUrl: string | null;
}

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

/** Websuche + LLM-Zusammenfassung für einen Kandidatennamen. Gibt null
 * zurück, wenn TAVILY_API_KEY fehlt, die Suche nichts findet, oder das LLM
 * nicht confident=true zurückgibt — Aufrufer behandeln null als "keine
 * verlässliche Anreicherung möglich", nie als Fehler. */
export async function enrichCandidateContext(
  entityType: "person" | "ensemble",
  name: string,
): Promise<EntityEnrichment | null> {
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
