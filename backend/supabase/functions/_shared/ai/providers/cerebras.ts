// Cerebras Inference API — OpenAI-kompatibel, 1 Mio. Tokens/Tag + 30
// Anfragen/Minute im Free-Tier (Stand 2026-07, laut Cerebras-Ankündigung ab
// 2026-08-17 mit hinterlegter Zahlungsmethode). Braucht CEREBRAS_API_KEY als
// Supabase-Secret (cloud.cerebras.ai -> API Keys).
//
// gpt-oss-120b statt z.B. llama-3.3-70b: Modellverfügbarkeit pro
// Account/Tier variiert bei Cerebras — bei einem 404 "model not found" die
// tatsächlich verfügbaren Modelle via GET /v1/models prüfen und hier
// anpassen.

import { createOpenAiCompatibleProvider } from "./openai-compatible.ts";

export const cerebrasProvider = createOpenAiCompatibleProvider({
  name: "cerebras",
  envKey: "CEREBRAS_API_KEY",
  apiBase: "https://api.cerebras.ai/v1/chat/completions",
  model: "gpt-oss-120b",
});
