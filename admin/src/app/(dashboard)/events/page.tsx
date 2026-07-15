import { createClient } from "@/lib/supabase/server";

// Event-Daten ändern sich häufig (Preise, Restkarten) — nie statisch cachen.
export const dynamic = "force-dynamic";

interface EventRow {
  id: string;
  slug: string;
  title: string;
  start_datetime: string;
  status: string;
  venues: { name: string } | null;
}

const STATUS_LABEL: Record<string, string> = {
  scheduled: "Geplant",
  sold_out: "Ausverkauft",
  cancelled: "Abgesagt",
  postponed: "Verschoben",
  draft: "Entwurf",
};

export default async function EventsPage() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("events")
    .select("id, slug, title, start_datetime, status, venues(name)")
    .order("start_datetime", { ascending: true })
    .limit(50)
    .returns<EventRow[]>();

  return (
    <div className="p-8">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Veranstaltungen</h1>
          <p className="text-sm text-neutral-500">
            Kommende Events, redaktionell prüfbar. Neu anlegen &amp; bearbeiten folgt in Phase 1.
          </p>
        </div>
      </div>

      {error && (
        <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Konnte Events nicht laden ({error.message}). Prüfe, ob{" "}
          <code className="font-mono">NEXT_PUBLIC_SUPABASE_URL</code> /{" "}
          <code className="font-mono">NEXT_PUBLIC_SUPABASE_ANON_KEY</code> gesetzt sind und das
          Schema migriert wurde (<code className="font-mono">supabase db push</code>).
        </div>
      )}

      {!error && (
        <div className="overflow-hidden rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500">
              <tr>
                <th className="px-4 py-3 font-medium">Titel</th>
                <th className="px-4 py-3 font-medium">Ort</th>
                <th className="px-4 py-3 font-medium">Termin</th>
                <th className="px-4 py-3 font-medium">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {data?.length ? (
                data.map((event) => (
                  <tr key={event.id} className="hover:bg-neutral-50">
                    <td className="px-4 py-3 font-medium text-neutral-900">{event.title}</td>
                    <td className="px-4 py-3 text-neutral-600">{event.venues?.name ?? "—"}</td>
                    <td className="px-4 py-3 text-neutral-600 tabular-nums">
                      {new Date(event.start_datetime).toLocaleString("de-DE", {
                        dateStyle: "medium",
                        timeStyle: "short",
                      })}
                    </td>
                    <td className="px-4 py-3">
                      <span className="rounded-full bg-neutral-100 px-2.5 py-1 text-xs font-medium text-neutral-700">
                        {STATUS_LABEL[event.status] ?? event.status}
                      </span>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-neutral-400">
                    Noch keine Veranstaltungen. Seed-Daten via{" "}
                    <code className="font-mono">supabase db reset</code> laden oder Import starten.
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
