"use client";

import { useState, useTransition } from "react";
import { assignRole, removeRole } from "./actions";

type AppRole = "admin" | "editor";

const ROLE_LABEL: Record<string, string> = {
  admin: "Admin",
  editor: "Redakteur",
};

const ROLE_STYLE: Record<string, string> = {
  admin: "bg-neutral-900 text-white",
  editor: "bg-neutral-100 text-neutral-700",
};

const ROLE_OPTIONS: { value: AppRole; label: string }[] = [
  { value: "editor", label: "Redakteur" },
  { value: "admin", label: "Admin" },
];

// Bewusst kein window.confirm()/alert() (mehr) — Browser unterdrücken
// wiederholte Dialoge nach ein paar Aufrufen automatisch, ein weiterer
// Klick tut dann optisch nichts. Inline-Bestätigung + Fehleranzeige statt
// nativer Dialoge, siehe components/confirm-button.tsx für dasselbe Muster.
export function RoleBadge({ userId, role }: { userId: string; role: string }) {
  const [pending, startTransition] = useTransition();
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (confirming) {
    return (
      <span className="inline-flex items-center gap-1.5 rounded-full bg-red-50 px-2.5 py-1 text-xs font-medium text-red-900">
        {ROLE_LABEL[role] ?? role} entziehen?
        <button
          type="button"
          disabled={pending}
          onClick={() => {
            startTransition(async () => {
              try {
                await removeRole(userId, role as AppRole);
              } catch (e) {
                setError(e instanceof Error ? e.message : "Rolle konnte nicht entzogen werden.");
                setConfirming(false);
              }
            });
          }}
          className="font-semibold underline decoration-dotted disabled:opacity-50"
        >
          {pending ? "…" : "Ja"}
        </button>
        <button type="button" disabled={pending} onClick={() => setConfirming(false)} className="opacity-70 hover:opacity-100">
          Nein
        </button>
      </span>
    );
  }

  return (
    <span className="inline-flex flex-col items-start gap-0.5">
      <span
        className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ${
          ROLE_STYLE[role] ?? "bg-neutral-100 text-neutral-700"
        }`}
      >
        {ROLE_LABEL[role] ?? role}
        <button
          type="button"
          disabled={pending}
          onClick={() => {
            setError(null);
            setConfirming(true);
          }}
          className="text-current opacity-60 hover:opacity-100 disabled:opacity-30"
          aria-label={`${ROLE_LABEL[role] ?? role}-Rolle entziehen`}
        >
          ×
        </button>
      </span>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </span>
  );
}

export function AssignRoleForm({ userId, existingRoles }: { userId: string; existingRoles: string[] }) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const available = ROLE_OPTIONS.filter((r) => !existingRoles.includes(r.value));

  if (available.length === 0) return null;

  return (
    <form
      action={(formData) => {
        const role = String(formData.get("role")) as AppRole;
        setError(null);
        startTransition(async () => {
          try {
            await assignRole(userId, role);
          } catch (e) {
            setError(e instanceof Error ? e.message : "Rolle konnte nicht zugewiesen werden.");
          }
        });
      }}
      className="flex flex-col items-start gap-1"
    >
      <div className="flex items-center gap-2">
        <select name="role" className="rounded-md border border-neutral-300 px-2 py-1 text-xs" defaultValue={available[0].value}>
          {available.map((r) => (
            <option key={r.value} value={r.value}>
              {r.label}
            </option>
          ))}
        </select>
        <button
          type="submit"
          disabled={pending}
          className="rounded-md bg-neutral-900 px-2.5 py-1 text-xs font-medium text-white hover:bg-neutral-700 disabled:opacity-50"
        >
          {pending ? "…" : "Zuweisen"}
        </button>
      </div>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
