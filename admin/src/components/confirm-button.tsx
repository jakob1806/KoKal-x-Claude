"use client";

import { useState, useTransition } from "react";

// Generalisierte Variante von DeleteButton für Aktionen, die zwar eine
// Bestätigung brauchen, aber nicht das rote "Löschen"-Styling/Label.
//
// Bewusst KEIN window.confirm() (mehr): Browser unterdrücken wiederholte
// confirm()-Dialoge nach ein paar Aufrufen automatisch (Chrome/Firefox
// bieten "Diese Seite daran hindern, weitere Dialoge zu erstellen" an) —
// jeder weitere Klick tut dann optisch NICHTS, ohne jeden Hinweis, warum.
// Inline-Bestätigung (Klick -> "Sicher?"-Zeile -> zweiter Klick) hat diese
// Falle nicht.
//
// Und: fängt jetzt den Fehlerfall der Server Action ab und zeigt ihn an,
// statt ihn als unbehandelte Promise-Rejection verschwinden zu lassen —
// vorher sah ein fehlgeschlagener Aufruf (falscher/veralteter Datensatz,
// Netzwerk-Hänger, RLS-Ablehnung) für den Nutzer identisch aus wie ein Klick,
// der gar nichts bewirkt.
export function ConfirmButton({
  action,
  confirmMessage,
  label,
  pendingLabel,
  className,
}: {
  action: () => Promise<void>;
  confirmMessage: string;
  label: string;
  pendingLabel: string;
  className?: string;
}) {
  const [pending, startTransition] = useTransition();
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (confirming) {
    return (
      <span className="inline-flex items-center gap-2 text-sm">
        <span className="text-neutral-600">{confirmMessage}</span>
        <button
          type="button"
          disabled={pending}
          onClick={() => {
            setError(null);
            startTransition(async () => {
              try {
                await action();
                setConfirming(false);
              } catch (e) {
                setError(e instanceof Error ? e.message : "Aktion fehlgeschlagen.");
                setConfirming(false);
              }
            });
          }}
          className="font-medium text-red-700 hover:text-red-900 disabled:opacity-50"
        >
          {pending ? pendingLabel : "Ja, sicher"}
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => setConfirming(false)}
          className="font-medium text-neutral-500 hover:text-neutral-700 disabled:opacity-50"
        >
          Abbrechen
        </button>
      </span>
    );
  }

  return (
    <span className="inline-flex flex-col items-end gap-1">
      <button
        type="button"
        disabled={pending}
        onClick={() => {
          setError(null);
          setConfirming(true);
        }}
        className={className ?? "text-sm font-medium text-neutral-700 hover:text-neutral-900 disabled:opacity-50"}
      >
        {label}
      </button>
      {error && <span className="max-w-xs text-right text-xs text-red-600">{error}</span>}
    </span>
  );
}
