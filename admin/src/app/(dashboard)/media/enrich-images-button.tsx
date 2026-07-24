"use client";

import { useState, useTransition } from "react";
import { enrichEntityImages, type EnrichImagesResult } from "./actions";

const KIND_LABEL: Record<string, string> = {
  venues: "Venues",
  persons: "Personen",
  ensembles: "Ensembles",
  festivals: "Festivals",
};

/** Löst einen Lauf der enrich-entity-images Edge Function aus — sucht
 * Wikimedia-Commons-Bilder für Entitäten ohne eigenes Foto (landen unten in
 * dieser Liste zur Prüfung) und übernimmt Venue-Fotos als Event-Titelbild,
 * wo noch keins existiert. Einmaliger Lauf pro Klick (im Gegensatz zum
 * mehrrundigen ResolveWithAiButton auf /entity-candidates) — hier gibt es
 * kein "restliche Warteliste abarbeiten"-Szenario, jeder Lauf deckt bereits
 * alle vier Entitäts-Arten in einem Rutsch ab. */
export function EnrichImagesButton() {
  const [pending, startTransition] = useTransition();
  const [result, setResult] = useState<EnrichImagesResult | null>(null);

  function run() {
    startTransition(async () => {
      setResult(await enrichEntityImages());
    });
  }

  const totalQueued = result?.perKind
    ? Object.values(result.perKind).reduce((sum, r) => sum + r.queued, 0)
    : 0;
  const allErrors = [
    ...(result?.perKind ? Object.values(result.perKind).flatMap((r) => r.errors) : []),
    ...(result?.events?.errors ?? []),
  ];

  return (
    <div className="flex flex-col items-end gap-2">
      <button
        type="button"
        disabled={pending}
        onClick={run}
        className="rounded-md bg-neutral-900 px-4 py-2 text-sm font-medium text-white hover:bg-neutral-700 disabled:opacity-50"
      >
        {pending ? "Suche läuft…" : "Bilder automatisch suchen"}
      </button>
      {result?.status === "failed" && (
        <p className="max-w-xs text-right text-xs text-red-600">{result.error}</p>
      )}
      {result?.status === "ok" && (
        <p className="max-w-xs text-right text-xs text-neutral-600">
          {totalQueued} neue Bilder zur Prüfung
          {result.perKind && (
            <>
              {" "}
              (
              {Object.entries(result.perKind)
                .map(([kind, r]) => `${KIND_LABEL[kind] ?? kind}: ${r.queued}/${r.found}`)
                .join(", ")}
              )
            </>
          )}
          {result.events && result.events.updated > 0 && (
            <> · {result.events.updated} Event-Titelbilder aus Venue-Fotos übernommen</>
          )}
          {allErrors.length > 0 && (
            <span className="mt-1 block text-amber-700">{allErrors.slice(0, 3).join("; ")}</span>
          )}
        </p>
      )}
    </div>
  );
}
