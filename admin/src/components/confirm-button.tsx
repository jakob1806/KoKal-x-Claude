"use client";

import { useTransition } from "react";

// Generalisierte Variante von DeleteButton für Aktionen, die zwar eine
// Bestätigung brauchen, aber nicht das rote "Löschen"-Styling/Label.
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

  return (
    <button
      type="button"
      disabled={pending}
      onClick={() => {
        if (window.confirm(confirmMessage)) {
          startTransition(action);
        }
      }}
      className={className ?? "text-sm font-medium text-neutral-700 hover:text-neutral-900 disabled:opacity-50"}
    >
      {pending ? pendingLabel : label}
    </button>
  );
}
