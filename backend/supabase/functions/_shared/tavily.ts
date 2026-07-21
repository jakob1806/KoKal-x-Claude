// Gemeinsamer Baustein für Websuche via Tavily (LLM-orientierte Search-API,
// liefert bereits aufbereitete Snippets statt roher HTML-Ergebnisseiten).
// Genutzt für die Anreicherung neu entdeckter entity_candidates (siehe
// enrich-event-references/index.ts): wenn ein unbekannter Gastkünstler-Name
// zum ersten Mal auftaucht, hilft eine kurze Websuche + Gemini-Zusammenfassung
// dem Redakteur im Review, statt nur einen nackten Namen zu sehen.
//
// Braucht TAVILY_API_KEY als Supabase-Secret (tavily.com -> API-Key erzeugen,
// dann `supabase secrets set TAVILY_API_KEY=...` oder im Dashboard unter
// Edge Functions > Secrets). Kostenloses Kontingent: 1000 Credits/Monat, ohne
// Kreditkarte (Stand 2026) — im Gegensatz zu Brave, das inzwischen ab der
// ersten Anfrage kostenpflichtig ist.

const TAVILY_API_BASE = "https://api.tavily.com/search";

export interface TavilyResult {
  title: string;
  url: string;
  content: string;
}

/** Führt eine einfache Tavily-Suche aus und gibt die Top-Treffer zurück, oder
 * null bei jedem Fehler (Netzwerk, HTTP-Fehler, fehlender/falscher Body) —
 * Aufrufer behandeln null wie "keine Anreicherung möglich", kein Werfen. */
export async function searchTavily(
  apiKey: string,
  query: string,
  maxResults = 3,
): Promise<TavilyResult[] | null> {
  let res: Response;
  try {
    res = await fetch(TAVILY_API_BASE, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        api_key: apiKey,
        query,
        max_results: maxResults,
        search_depth: "basic",
      }),
    });
  } catch {
    return null;
  }
  if (!res.ok) return null;

  // deno-lint-ignore no-explicit-any
  let data: any;
  try {
    data = await res.json();
  } catch {
    return null;
  }

  const results = data?.results;
  if (!Array.isArray(results)) return null;

  return results
    // deno-lint-ignore no-explicit-any
    .filter((r: any) => r != null && typeof r.title === "string" && typeof r.url === "string")
    // deno-lint-ignore no-explicit-any
    .map((r: any) => ({
      title: r.title,
      url: r.url,
      content: typeof r.content === "string" ? r.content : "",
    }));
}
