// NVIDIA NIM (build.nvidia.com) — OpenAI-kompatibel, 40 Anfragen/Minute ohne
// erwähntes Tageslimit im Free-Tier (Stand 2026-07), kein Kreditkarte nötig.
// Braucht NVIDIA_API_KEY als Supabase-Secret (build.nvidia.com -> API Key).
//
// Modell-ID nicht live verifiziert (NVIDIA_API_KEY war zum Zeitpunkt dieser
// Umstellung noch nicht hinterlegt) — bei einem 404 die tatsächlich
// verfügbaren Modelle via GET https://integrate.api.nvidia.com/v1/models
// prüfen und hier anpassen (gleiches Vorgehen wie bei den anderen Providern
// nötig war).

import { createOpenAiCompatibleProvider } from "./openai-compatible.ts";

export const nvidiaProvider = createOpenAiCompatibleProvider({
  name: "nvidia",
  envKey: "NVIDIA_API_KEY",
  apiBase: "https://integrate.api.nvidia.com/v1/chat/completions",
  model: "meta/llama-3.3-70b-instruct",
});
