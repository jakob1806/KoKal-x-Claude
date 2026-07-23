import { ConfirmButton } from "@/components/confirm-button";
import { createClient } from "@/lib/supabase/server";
import { approveEntityCandidate, mergeEntityCandidate, rejectEntityCandidate } from "./actions";

export const dynamic = "force-dynamic";

const ENTITY_TYPE_LABEL: Record<string, string> = {
  person: "Person",
  ensemble: "Ensemble",
  organizer: "Institution",
};

interface CandidateRow {
  id: string;
  entity_type: string;
  name: string;
  suggested_event_title: string | null;
  suggested_event_start_datetime: string | null;
  source_url: string | null;
  created_at: string;
  venue: { name: string } | null;
  discovery_context: {
    tavily?: { bioSnippet: string | null; websiteUrl: string | null };
    possible_match?: { id: string; name: string; similarity: number };
  } | null;
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("de-DE", { dateStyle: "medium", timeStyle: "short" });
}

export default async function EntityCandidatesPage() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("entity_candidates")
    .select(
      `id, entity_type, name, suggested_event_title, suggested_event_start_datetime, source_url, created_at,
       discovery_context, venue:venues(name)`,
    )
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .returns<CandidateRow[]>();

  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Entity-Kandidaten</h1>
      <p className="mt-1 max-w-xl text-sm text-neutral-500">
        Bisher unbekannte Personen/Ensembles/Institutionen aus der Ingestion — vor dem Anlegen in den Stammdaten hier
        prüfen und freigeben.
      </p>

      {error && <p className="mt-6 text-sm text-amber-700">Konnte Kandidaten nicht laden: {error.message}</p>}

      {!error && (
        <div className="mt-6 flex flex-col gap-3">
          {data?.length ? (
            data.map((candidate) => (
              <div key={candidate.id} className="rounded-lg border border-neutral-200 bg-white p-4">
                <div className="flex items-center justify-between gap-4">
                  <span className="text-xs text-neutral-400">
                    Gefunden {formatDate(candidate.created_at)} · {ENTITY_TYPE_LABEL[candidate.entity_type] ?? candidate.entity_type}
                  </span>
                </div>
                <div className="mt-3 rounded-md border border-neutral-100 bg-neutral-50 p-3">
                  <p className="text-sm font-medium text-neutral-900">{candidate.name}</p>
                  {candidate.suggested_event_title && (
                    <p className="mt-1 text-xs text-neutral-500">
                      Anlass: {candidate.suggested_event_title}
                      {candidate.venue?.name ? ` · ${candidate.venue.name}` : ""}
                      {candidate.suggested_event_start_datetime
                        ? ` · ${formatDate(candidate.suggested_event_start_datetime)}`
                        : ""}
                    </p>
                  )}
                  {candidate.source_url && (
                    <a
                      href={candidate.source_url}
                      target="_blank"
                      rel="noreferrer"
                      className="mt-1 block truncate text-xs text-blue-600 hover:underline"
                    >
                      {candidate.source_url}
                    </a>
                  )}
                  {candidate.discovery_context?.tavily?.bioSnippet && (
                    <p className="mt-2 text-xs text-neutral-600">
                      {candidate.discovery_context.tavily.bioSnippet}
                    </p>
                  )}
                  {candidate.discovery_context?.tavily?.websiteUrl && (
                    <a
                      href={candidate.discovery_context.tavily.websiteUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="mt-1 block truncate text-xs text-blue-600 hover:underline"
                    >
                      {candidate.discovery_context.tavily.websiteUrl}
                    </a>
                  )}
                  {candidate.discovery_context?.possible_match && (
                    <p className="mt-2 rounded bg-amber-50 px-2 py-1 text-xs text-amber-800">
                      Möglicherweise identisch mit „{candidate.discovery_context.possible_match.name}“ (
                      {Math.round(candidate.discovery_context.possible_match.similarity * 100)}% Ähnlichkeit) —
                      bereits vorhanden.
                    </p>
                  )}
                </div>
                <div className="mt-4 flex items-center justify-end gap-4">
                  <ConfirmButton
                    action={rejectEntityCandidate.bind(null, candidate.id)}
                    confirmMessage="Kandidat ablehnen? Es wird keine Person/kein Ensemble angelegt."
                    label="Ablehnen"
                    pendingLabel="Speichere…"
                    className="text-sm font-medium text-neutral-600 hover:text-neutral-900 disabled:opacity-50"
                  />
                  {candidate.discovery_context?.possible_match && (
                    <ConfirmButton
                      action={mergeEntityCandidate.bind(
                        null,
                        candidate.id,
                        candidate.discovery_context.possible_match.id,
                      )}
                      confirmMessage={`Mit „${candidate.discovery_context.possible_match.name}“ zusammenführen? Es wird KEIN neuer Stammdaten-Eintrag angelegt.`}
                      label="Zusammenführen"
                      pendingLabel="Speichere…"
                      className="text-sm font-medium text-amber-700 hover:text-amber-900 disabled:opacity-50"
                    />
                  )}
                  <ConfirmButton
                    action={approveEntityCandidate.bind(null, candidate.id)}
                    confirmMessage="Freigeben? Legt einen neuen (unverifizierten) Stammdaten-Eintrag an."
                    label="Freigeben"
                    pendingLabel="Speichere…"
                    className="text-sm font-medium text-emerald-700 hover:text-emerald-900 disabled:opacity-50"
                  />
                </div>
              </div>
            ))
          ) : (
            <div className="rounded-lg border border-dashed border-neutral-300 bg-white px-4 py-10 text-center text-sm text-neutral-400">
              Keine offenen Entity-Kandidaten.
            </div>
          )}
        </div>
      )}
    </div>
  );
}
