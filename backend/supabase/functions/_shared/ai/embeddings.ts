// Embedding-Erzeugung für semantische Empfehlungen (Architektur-Dokument
// Abschnitt 2.2/11) — bewusst NICHT Teil des callAiFunction-Providerkreises
// in router.ts: Cerebras/NVIDIA sind hier als Chat-Completion-Modelle
// eingebunden, kein Embedding-Endpoint; Gemini bietet mit gemini-embedding-001
// (kostenlos im selben Free-Tier wie die Chat-Modelle) einen passenden
// Endpoint. Braucht GEMINI_API_KEY (denselben Key wie
// _shared/ai/providers/gemini.ts).
//
// "text-embedding-004" (das ursprünglich naheliegende Modell) existiert
// nicht mehr (404) — wie beim Chat-Modell schon einmal in dieser Session
// deprecatet Google Embedding-Modelle offenbar genauso häufig. Aktuell
// verfügbar (Stand 2026-07, per GET /v1beta/models geprüft):
// gemini-embedding-001 (stabil), gemini-embedding-2(-preview). Nutzt
// outputDimensionality:768, um zur festen Spaltengröße
// events.embedding vector(768) zu passen (20260819000009_embeddings.sql)
// — ohne den Parameter liefert das Modell eine andere Standardgröße.
//
// Falls Gemini künftig auch hier ausfällt: gleiches Fallback-Prinzip wie
// beim Router anwenden (weiterer Provider in einer Kette) statt wieder
// blind auf einen einzelnen Provider zu setzen.

const EMBEDDING_MODEL = "gemini-embedding-001";
const EMBEDDING_DIMENSIONS = 768;
const EMBEDDING_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

/** Gibt einen 768-dimensionalen Embedding-Vektor zurück, oder null bei
 * jedem Fehler (fehlender Key, Netzwerkfehler, HTTP-Fehler, leerer Text) —
 * Aufrufer überspringen das Event bei null statt abzubrechen. */
export async function embedText(text: string): Promise<number[] | null> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey || !text.trim()) return null;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);

  let res: Response;
  try {
    res = await fetch(`${EMBEDDING_API_BASE}/${EMBEDDING_MODEL}:embedContent`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        model: `models/${EMBEDDING_MODEL}`,
        content: { parts: [{ text }] },
        outputDimensionality: EMBEDDING_DIMENSIONS,
      }),
      signal: controller.signal,
    });
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
  if (!res.ok) return null;

  // deno-lint-ignore no-explicit-any
  let data: any;
  try {
    data = await res.json();
  } catch {
    return null;
  }

  const values = data?.embedding?.values;
  if (!Array.isArray(values) || values.length === 0) return null;
  return values;
}
