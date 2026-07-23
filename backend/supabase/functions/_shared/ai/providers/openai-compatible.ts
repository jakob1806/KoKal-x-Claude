// Gemeinsame Basis für alle Provider, die eine OpenAI-kompatible
// Chat-Completions-API mit Tool-Calling anbieten (Cerebras, NVIDIA NIM, und
// potenziell weitere). Anders als Gemini liefern diese APIs die
// Funktionsargumente als JSON-STRING
// (message.tool_calls[].function.arguments), nicht als bereits geparstes
// Objekt — wird hier einmalig geparst, damit der Rückgabetyp für alle
// Provider identisch ist.
//
// TIMEOUT_MS begrenzt jeden einzelnen Aufruf hart: NVIDIA NIM antwortet
// z.B. konstant erst nach 10-13s (kein Cold-Start-Einzelfall, sondern
// reguläre Latenz dieses Endpoints) — ohne Limit kann ein einzelner
// langsamer/hängender Provider bei mehreren Events in Folge die gesamte
// Edge Function ins Compute-Timeout laufen lassen (WORKER_RESOURCE_LIMIT).
// Ein Timeout wird wie jeder andere Fehler behandelt: null zurück, Router
// probiert den nächsten Provider.

import type { AiFunctionDeclaration, AiProvider } from "../types.ts";

const TIMEOUT_MS = 20000;

export function createOpenAiCompatibleProvider(opts: {
  name: string;
  envKey: string;
  apiBase: string;
  model: string;
}): AiProvider {
  return {
    name: opts.name,
    envKey: opts.envKey,
    async callFunction(system: string, user: string, fn: AiFunctionDeclaration) {
      const apiKey = Deno.env.get(opts.envKey);
      if (!apiKey) return null;

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);

      let res: Response;
      try {
        res = await fetch(opts.apiBase, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            authorization: `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model: opts.model,
            messages: [
              { role: "system", content: system },
              { role: "user", content: user },
            ],
            tools: [{
              type: "function",
              function: { name: fn.name, description: fn.description, parameters: fn.parameters },
            }],
            tool_choice: { type: "function", function: { name: fn.name } },
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

      const toolCalls = data?.choices?.[0]?.message?.tool_calls;
      if (!Array.isArray(toolCalls) || toolCalls.length === 0) return null;
      // deno-lint-ignore no-explicit-any
      const call = toolCalls.find((c: any) => c?.function?.name === fn.name) ?? toolCalls[0];
      if (typeof call?.function?.arguments !== "string") return null;

      try {
        return JSON.parse(call.function.arguments);
      } catch {
        return null;
      }
    },
  };
}
