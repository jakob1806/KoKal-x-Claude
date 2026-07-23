"use client";

import { useState, useTransition } from "react";
import { resolveEntityCandidatesWithAi } from "./actions";

/** Batch-Button: schickt bis zu 12 wartende person/ensemble-Kandidaten durch
 * dieselbe Tavily+LLM-Prüfung, die neue Kandidaten schon automatisch
 * entscheidet (siehe resolve-entity-candidates Edge Function) — holt das
 * für die schon bestehende Warteliste nach, die von der laufenden
 * Automatik nicht rückwirkend erfasst wird. Einfach mehrfach klicken, um
 * weitere 12 abzuarbeiten — bewusst klein gehalten, ein zu großer Batch
 * hat zuvor das Edge-Function-Timeout gerissen und den Button ohne
 * Rückmeldung hängen lassen. */
export function ResolveWithAiButton() {
  const [pending, startTransition] = useTransition();
  const [result, setResult] = useState<Awaited<ReturnType<typeof resolveEntityCandidatesWithAi>> | null>(null);

  return (
    <div className="flex flex-col items-end gap-2">
      <button
        type="button"
        disabled={pending}
        onClick={() => {
          setResult(null);
          startTransition(async () => {
            setResult(await resolveEntityCandidatesWithAi());
          });
        }}
        className="rounded-md bg-neutral-900 px-4 py-2 text-sm font-medium text-white hover:bg-neutral-700 disabled:opacity-50"
      >
        {pending ? "KI prüft…" : "Mit KI prüfen (bis zu 12)"}
      </button>
      {result?.status === "ok" && (
        <p className="max-w-xs text-right text-xs text-neutral-600">
          {result.processed ?? 0} geprüft · {result.approved ?? 0} automatisch angelegt · {result.leftPending ?? 0}{" "}
          weiterhin unklar
          {result.errors && result.errors.length > 0 && (
            <span className="mt-1 block text-red-600">{result.errors.join("; ")}</span>
          )}
        </p>
      )}
      {result?.status === "failed" && <p className="max-w-xs text-right text-xs text-red-600">{result.error}</p>}
    </div>
  );
}
