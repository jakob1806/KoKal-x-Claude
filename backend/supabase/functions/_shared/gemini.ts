// Gemeinsamer Baustein für strukturierte Extraktion via Google Gemini API
// (Function Calling) — ersetzt die zuvor Anthropic-spezifische Tool-Use-
// Logik in enrich-event-references/index.ts und
// extract-event-from-url/llm.ts. Umstieg auf Gemini statt Anthropic: Google
// bietet (Stand 2026) ein DAUERHAFTES Gratis-Kontingent, nicht nur ein
// zeitlich begrenztes Test-Guthaben wie Anthropic/OpenAI — für den Start
// ohne laufende Kosten.
//
// GEMINI_MODEL bewusst auf den "-latest"-Alias statt eines fest versionierten
// Modellnamens (z.B. "gemini-2.0-flash") gesetzt: Google deprecatet einzelne
// Modellversionen regelmäßig (2026-07 z.B. mit Kontingent 0 für
// gemini-2.0-flash und 404 "no longer available to new users" für
// gemini-2.5-flash), während der -latest-Alias automatisch auf das jeweils
// aktuell unterstützte Free-Tier-Flash-Modell zeigt (aktuell gemini-3.6-flash
// dahinter). Falls trotzdem wieder ein 404/429 auftritt: aktuellen Stand in
// Google AI Studio (aistudio.google.com) prüfen.
//
// Braucht GEMINI_API_KEY als Supabase-Secret (Google AI Studio -> "Get API
// key", dann `supabase secrets set GEMINI_API_KEY=...` oder im Dashboard
// unter Edge Functions > Secrets).

const GEMINI_MODEL = "gemini-flash-latest";
const GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

export interface GeminiFunctionDeclaration {
  name: string;
  description: string;
  // Gemini nutzt ein OpenAPI-Schema-Subset: type-Werte GROSSGESCHRIEBEN
  // ("OBJECT"/"STRING"/"ARRAY"/...), Nullable-Felder über `nullable: true`
  // statt eines type-Arrays wie ["string","null"] (Anthropic/JSON-Schema-
  // Konvention) — beim Definieren einer neuen Funktion daran halten.
  // deno-lint-ignore no-explicit-any
  parameters: Record<string, any>;
}

/** Ruft Gemini mit erzwungenem Function-Call auf (analog zu Anthropics
 * tool_choice: {type:"tool", name:...}) — mode:"ANY" + allowed_function_names
 * zwingt das Modell, GENAU diese eine Funktion aufzurufen statt frei zu
 * antworten. Gibt die bereits geparsten Funktions-Argumente zurück (Gemini
 * liefert sie als Objekt, kein JSON-String zum Nachparsen wie bei manchen
 * anderen APIs) oder null bei jedem Fehler (Netzwerk, HTTP-Fehler, fehlender
 * Function-Call) — Aufrufer behandeln null wie einen fehlgeschlagenen
 * Aufruf: kein Werfen, einfach überspringen und mit dem nächsten Item
 * weitermachen (gleiches Verhalten wie zuvor bei einem Anthropic-Fehler). */
export async function callGeminiFunction(
  apiKey: string,
  systemInstruction: string,
  userText: string,
  fn: GeminiFunctionDeclaration,
  // deno-lint-ignore no-explicit-any
): Promise<Record<string, any> | null> {
  let res: Response;
  try {
    res = await fetch(`${GEMINI_API_BASE}/${GEMINI_MODEL}:generateContent`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: systemInstruction }] },
        contents: [{ role: "user", parts: [{ text: userText }] }],
        tools: [{ functionDeclarations: [fn] }],
        tool_config: {
          function_calling_config: { mode: "ANY", allowed_function_names: [fn.name] },
        },
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

  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return null;
  // deno-lint-ignore no-explicit-any
  const withCall = parts.find((p: any) => p != null && typeof p === "object" && p.functionCall);
  const functionCall = withCall?.functionCall;
  if (!functionCall || functionCall.name !== fn.name || typeof functionCall.args !== "object") {
    return null;
  }
  return functionCall.args;
}
