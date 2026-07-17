"use client";

import Link from "next/link";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { extractEventsFromUrl } from "./actions";
import { INITIAL_STATE } from "./types";

const OUTCOME_LABEL: Record<string, string> = {
  created: "Neu angelegt",
  updated: "Aktualisiert",
  unchanged: "Unverändert",
  flagged: "Als Duplikat markiert",
  error: "Fehler",
};

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-md bg-neutral-900 px-4 py-2 text-sm font-medium text-white hover:bg-neutral-700 disabled:opacity-50"
    >
      {pending ? "Extrahiere…" : "Extrahieren"}
    </button>
  );
}

export default function EventsFromUrlPage() {
  const [state, formAction] = useActionState(extractEventsFromUrl, INITIAL_STATE);

  return (
    <div className="p-8">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Event(s) per URL hinzufügen</h1>
          <p className="text-sm text-neutral-500">
            Ein Link zu einem einzelnen Konzert oder zu einem ganzen Programm mit mehreren
            Terminen — beides wird automatisch erkannt und als Entwurf angelegt.
          </p>
        </div>
        <Link href="/events" className="text-sm font-medium text-neutral-700 hover:text-neutral-900">
          Zurück zu Veranstaltungen
        </Link>
      </div>

      <form action={formAction} className="max-w-2xl rounded-lg border border-neutral-200 bg-white p-6">
        <label htmlFor="url" className="block text-sm font-medium text-neutral-900">
          URL
        </label>
        <input
          id="url"
          name="url"
          type="url"
          required
          placeholder="https://…"
          className="mt-2 w-full rounded-md border border-neutral-300 px-3 py-2 text-sm focus:border-neutral-500 focus:outline-none"
        />
        <div className="mt-4">
          <SubmitButton />
        </div>
      </form>

      {state.status === "success" && (
        <div className="mt-6 max-w-2xl rounded-lg border border-emerald-200 bg-emerald-50 p-6">
          <p className="text-sm font-medium text-emerald-900">
            {state.eventsFound} Veranstaltung(en) erkannt (
            {state.extractionMethod === "llm" ? "KI-Extraktion" : "Schema.org"}) —{" "}
            {state.eventsCreated} neu, {state.eventsUpdated} aktualisiert
            {state.eventsFlaggedForReview ? `, ${state.eventsFlaggedForReview} als Duplikat markiert` : ""}.
          </p>
          {state.results && state.results.length > 0 && (
            <ul className="mt-3 space-y-1 text-sm text-emerald-800">
              {state.results.map((r, i) => (
                <li key={i}>
                  {OUTCOME_LABEL[r.outcome] ?? r.outcome}: {r.title}
                  {r.error ? ` — ${r.error}` : ""}
                </li>
              ))}
            </ul>
          )}
          {state.errors && state.errors.length > 0 && (
            <details className="mt-3 text-sm text-amber-800">
              <summary className="cursor-pointer">{state.errors.length} Hinweis(e)</summary>
              <ul className="mt-1 list-disc space-y-1 pl-4">
                {state.errors.map((e, i) => (
                  <li key={i}>{e}</li>
                ))}
              </ul>
            </details>
          )}
          <Link
            href="/events"
            className="mt-4 inline-block text-sm font-medium text-emerald-900 underline underline-offset-2"
          >
            Zu den Entwürfen →
          </Link>
        </div>
      )}

      {state.status === "failed" && (
        <div className="mt-6 max-w-2xl rounded-lg border border-red-200 bg-red-50 p-6">
          <p className="text-sm font-medium text-red-900">{state.error}</p>
          {state.errors && state.errors.length > 0 && (
            <ul className="mt-2 list-disc space-y-1 pl-4 text-sm text-red-800">
              {state.errors.map((e, i) => (
                <li key={i}>{e}</li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
