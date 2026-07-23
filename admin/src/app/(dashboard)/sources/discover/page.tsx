"use client";

import Link from "next/link";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { discoverSources } from "./actions";
import { INITIAL_STATE } from "./types";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-md bg-neutral-900 px-4 py-2 text-sm font-medium text-white hover:bg-neutral-700 disabled:opacity-50"
    >
      {pending ? "Suche läuft… (kann bis zu einer Minute dauern)" : "Suchen"}
    </button>
  );
}

export default function DiscoverSourcesPage() {
  const [state, formAction] = useActionState(discoverSources, INITIAL_STATE);

  return (
    <div className="p-8">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Neue Quellen entdecken</h1>
          <p className="max-w-xl text-sm text-neutral-500">
            Freitext-Suchbegriff eingeben (z.B. „klassische Konzerte Kammermusik München Veranstalter“) — das System
            sucht per Websuche nach bisher unbekannten Veranstaltern und schlägt Treffer als Kandidaten zur
            Freigabe vor. Legt nichts automatisch an; jeder Lauf kostet Such-/KI-Credits, daher nur manuell auslösbar.
          </p>
        </div>
        <Link href="/sources" className="text-sm font-medium text-neutral-700 hover:text-neutral-900">
          Zurück zu Datenquellen
        </Link>
      </div>

      <form action={formAction} className="max-w-2xl rounded-lg border border-neutral-200 bg-white p-6">
        <label htmlFor="query" className="block text-sm font-medium text-neutral-900">
          Suchbegriff
        </label>
        <input
          id="query"
          name="query"
          type="text"
          required
          placeholder="klassische Konzerte Kammermusik München Veranstalter"
          className="mt-2 w-full rounded-md border border-neutral-300 px-3 py-2 text-sm focus:border-neutral-500 focus:outline-none"
        />
        <div className="mt-4">
          <SubmitButton />
        </div>
      </form>

      {state.status === "ok" && (
        <div className="mt-6 max-w-2xl rounded-lg border border-emerald-200 bg-emerald-50 p-6">
          <p className="text-sm font-medium text-emerald-900">
            {state.candidatesFound ?? 0} Kandidat(en) gefunden, {state.created ?? 0} neu zur Freigabe angelegt.
          </p>
          <p className="mt-1 text-sm text-emerald-800">
            {state.skippedKnown ?? 0} bereits bekannt übersprungen
            {(state.skippedDuplicatePending ?? 0) > 0
              ? `, ${state.skippedDuplicatePending} bereits als offener Kandidat vorhanden`
              : ""}
            .
          </p>
          {state.note && <p className="mt-2 text-sm text-emerald-800">{state.note}</p>}
          {(state.created ?? 0) > 0 && (
            <Link
              href="/entity-candidates"
              className="mt-4 inline-block rounded-md bg-emerald-700 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-800"
            >
              Kandidaten prüfen →
            </Link>
          )}
        </div>
      )}

      {state.status === "failed" && (
        <div className="mt-6 max-w-2xl rounded-lg border border-red-200 bg-red-50 p-6">
          <p className="text-sm font-medium text-red-900">{state.error}</p>
        </div>
      )}
    </div>
  );
}
