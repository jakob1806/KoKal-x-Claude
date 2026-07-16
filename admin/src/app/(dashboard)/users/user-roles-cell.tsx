"use client";

import { useTransition } from "react";
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

export function RoleBadge({ userId, role }: { userId: string; role: string }) {
  const [pending, startTransition] = useTransition();

  return (
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
          if (!window.confirm(`Rolle "${ROLE_LABEL[role] ?? role}" wirklich entziehen?`)) return;
          startTransition(async () => {
            try {
              await removeRole(userId, role as AppRole);
            } catch (e) {
              alert(e instanceof Error ? e.message : "Rolle konnte nicht entzogen werden.");
            }
          });
        }}
        className="text-current opacity-60 hover:opacity-100 disabled:opacity-30"
        aria-label={`${ROLE_LABEL[role] ?? role}-Rolle entziehen`}
      >
        ×
      </button>
    </span>
  );
}

export function AssignRoleForm({ userId, existingRoles }: { userId: string; existingRoles: string[] }) {
  const [pending, startTransition] = useTransition();
  const available = ROLE_OPTIONS.filter((r) => !existingRoles.includes(r.value));

  if (available.length === 0) return null;

  return (
    <form
      action={(formData) => {
        const role = String(formData.get("role")) as AppRole;
        startTransition(async () => {
          try {
            await assignRole(userId, role);
          } catch (e) {
            alert(e instanceof Error ? e.message : "Rolle konnte nicht zugewiesen werden.");
          }
        });
      }}
      className="flex items-center gap-2"
    >
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
    </form>
  );
}
