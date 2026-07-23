import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

// Architektur-Dokument Abschnitt 7: EINE Review-Queue statt vier getrennter
// Seiten, die man einzeln kennen/anklicken muss. Verlinkt weiterhin auf die
// bestehenden spezialisierten Seiten (entity-candidates/duplicates/
// cancellations behalten ihre eigenen Freigabe-Aktionen — die hier nur zu
// duplizieren würde vier Codepfade für dieselbe Sache schaffen), zeigt aber
// zusätzlich Events mit niedrigem import_confidence-Score, für die es bisher
// GAR KEINE eigene Ansicht gab (der Score wurde bisher nur berechnet und
// gespeichert, siehe 20260819000004_events_import_confidence.sql, aber
// nirgends redaktionell sichtbar gemacht). Filtert über review_status statt
// eines global fixen Scores — die Triage-Schwellwerte sind pro Quelle
// kalibriert (sources.confidence_thresholds, siehe ingest-source/write.ts
// reviewStatusForScore()), ein globaler Cutoff hier würde das wieder blind
// dafür machen.
const REVIEW_STATUSES_TO_SHOW = ["needs_review", "needs_quick_check"] as const;

interface LowConfidenceEvent {
  id: string;
  title: string;
  start_datetime: string;
  status: string;
  import_confidence: number;
  venue: { name: string } | null;
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("de-DE", { dateStyle: "medium", timeStyle: "short" });
}

export default async function ReviewQueuePage() {
  const supabase = await createClient();

  const [
    { count: entityCandidateCount },
    { count: duplicateCount },
    { count: cancellationCount },
    { data: lowConfidenceEvents, error: lowConfidenceError },
  ] = await Promise.all([
    supabase.from("entity_candidates").select("id", { count: "exact", head: true }).eq("status", "pending"),
    supabase.from("duplicate_candidates").select("id", { count: "exact", head: true }).eq("status", "pending"),
    supabase.from("cancellation_candidates").select("id", { count: "exact", head: true }).eq("status", "pending"),
    supabase
      .from("events")
      .select("id, title, start_datetime, status, import_confidence, venue:venues(name)")
      .in("review_status", REVIEW_STATUSES_TO_SHOW)
      .order("import_confidence", { ascending: true })
      .limit(30)
      .returns<LowConfidenceEvent[]>(),
  ]);

  const summaryCards = [
    { href: "/entity-candidates", label: "Entity-Kandidaten", count: entityCandidateCount ?? 0 },
    { href: "/duplicates", label: "Duplikate", count: duplicateCount ?? 0 },
    { href: "/cancellations", label: "Absage-Kandidaten", count: cancellationCount ?? 0 },
  ];

  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Review-Queue</h1>
      <p className="mt-1 max-w-xl text-sm text-neutral-500">
        Alle offenen redaktionellen Prüfpunkte an einem Ort.
      </p>

      <div className="mt-6 grid grid-cols-3 gap-4">
        {summaryCards.map((card) => (
          <Link
            key={card.href}
            href={card.href}
            className="rounded-lg border border-neutral-200 bg-white p-5 hover:border-neutral-400"
          >
            <p className="text-2xl font-semibold text-neutral-900">{card.count}</p>
            <p className="mt-1 text-sm text-neutral-500">{card.label}</p>
          </Link>
        ))}
      </div>

      <h2 className="mt-10 text-sm font-semibold uppercase tracking-wide text-neutral-500">
        Events mit niedrigem Confidence-Score (quellenspezifisch kalibriert)
      </h2>

      {lowConfidenceError && (
        <p className="mt-4 text-sm text-amber-700">Konnte Events nicht laden: {lowConfidenceError.message}</p>
      )}

      {!lowConfidenceError && (
        <div className="mt-4 overflow-hidden rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500">
              <tr>
                <th className="px-4 py-3 font-medium">Titel</th>
                <th className="px-4 py-3 font-medium">Venue</th>
                <th className="px-4 py-3 font-medium">Termin</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium">Score</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {lowConfidenceEvents?.length ? (
                lowConfidenceEvents.map((e) => (
                  <tr key={e.id} className="hover:bg-neutral-50">
                    <td className="px-4 py-3 font-medium text-neutral-900">{e.title}</td>
                    <td className="px-4 py-3 text-neutral-600">{e.venue?.name ?? "—"}</td>
                    <td className="px-4 py-3 text-neutral-600">{formatDate(e.start_datetime)}</td>
                    <td className="px-4 py-3 text-neutral-600">{e.status}</td>
                    <td className="px-4 py-3 text-amber-700">{Math.round(e.import_confidence * 100)}%</td>
                    <td className="px-4 py-3 text-right">
                      <Link href={`/events/${e.id}`} className="text-sm font-medium text-neutral-700 hover:text-neutral-900">
                        Prüfen →
                      </Link>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="px-4 py-10 text-center text-neutral-400">
                    Keine Events mit niedrigem Confidence-Score.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
