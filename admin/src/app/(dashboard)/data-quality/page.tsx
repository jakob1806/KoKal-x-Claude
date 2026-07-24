import Link from "next/link";
import { ConfirmButton } from "@/components/confirm-button";
import { createClient } from "@/lib/supabase/server";
import { markEventVerified } from "./actions";

export const dynamic = "force-dynamic";

// Ab wann gilt ein bevorstehendes Event als "veraltet" i.S.d. wöchentlichen
// Datenqualitäts-Review (siehe docs/07-roadmap.md, "Kontinuierlich")? 14 Tage
// ohne erneute Quellen-Verifikation heißt: Preis/Absage-Status könnte sich
// unbemerkt geändert haben, seit last_verified_at zuletzt gesetzt wurde.
const STALE_AFTER_DAYS = 14;

interface EventRow {
  id: string;
  slug: string;
  title: string;
  start_datetime: string;
  image_urls: string[] | null;
  last_verified_at: string | null;
  venues: { name: string } | { name: string }[] | null;
}

function venueName(venues: EventRow["venues"]) {
  if (!venues) return null;
  return Array.isArray(venues) ? venues[0]?.name ?? null : venues.name;
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("de-DE", { dateStyle: "medium", timeStyle: "short" });
}

export default async function DataQualityPage() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("events")
    .select("id, slug, title, start_datetime, image_urls, last_verified_at, venues(name)")
    .in("status", ["scheduled", "sold_out", "postponed"])
    .gte("start_datetime", new Date().toISOString())
    .order("start_datetime", { ascending: true })
    .returns<EventRow[]>();

  const events = data ?? [];
  const missingImages = events.filter((e) => !e.image_urls || e.image_urls.length === 0);

  const staleCutoff = Date.now() - STALE_AFTER_DAYS * 24 * 60 * 60 * 1000;
  const staleEvents = events
    .filter((e) => !e.last_verified_at || new Date(e.last_verified_at).getTime() < staleCutoff)
    .sort((a, b) => {
      if (!a.last_verified_at) return -1;
      if (!b.last_verified_at) return 1;
      return new Date(a.last_verified_at).getTime() - new Date(b.last_verified_at).getTime();
    });

  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Datenqualität</h1>
      <p className="mt-1 max-w-xl text-sm text-neutral-500">
        Wöchentliche Review-Basis für bevorstehende Veranstaltungen: fehlende Bilder und Events, deren
        Quelle seit mehr als {STALE_AFTER_DAYS} Tagen nicht erneut geprüft wurde.
      </p>

      {error && (
        <p className="mt-6 text-sm text-amber-700">Konnte Events nicht laden: {error.message}</p>
      )}

      {!error && (
        <>
          <section className="mt-8">
            <h2 className="text-sm font-semibold text-neutral-700">
              Fehlende Bilder ({missingImages.length})
            </h2>
            <div className="mt-3 flex flex-col gap-2">
              {missingImages.length ? (
                missingImages.map((e) => (
                  <div
                    key={e.id}
                    className="flex items-center justify-between gap-4 rounded-lg border border-neutral-200 bg-white px-4 py-3"
                  >
                    <div>
                      <p className="text-sm font-medium text-neutral-900">{e.title}</p>
                      <p className="text-xs text-neutral-400">
                        {venueName(e.venues) ?? "—"} · {formatDate(e.start_datetime)}
                      </p>
                    </div>
                    <Link
                      href={`/events/${e.id}`}
                      className="shrink-0 text-sm font-medium text-blue-600 hover:underline"
                    >
                      Bearbeiten
                    </Link>
                  </div>
                ))
              ) : (
                <div className="rounded-lg border border-dashed border-neutral-300 bg-white px-4 py-8 text-center text-sm text-neutral-400">
                  Alle bevorstehenden Events haben mindestens ein Bild.
                </div>
              )}
            </div>
          </section>

          <section className="mt-10">
            <h2 className="text-sm font-semibold text-neutral-700">
              Veraltete Events ({staleEvents.length})
            </h2>
            <div className="mt-3 flex flex-col gap-2">
              {staleEvents.length ? (
                staleEvents.map((e) => (
                  <div
                    key={e.id}
                    className="flex items-center justify-between gap-4 rounded-lg border border-neutral-200 bg-white px-4 py-3"
                  >
                    <div>
                      <p className="text-sm font-medium text-neutral-900">{e.title}</p>
                      <p className="text-xs text-neutral-400">
                        {venueName(e.venues) ?? "—"} · {formatDate(e.start_datetime)}
                      </p>
                      <p className="mt-1 text-xs text-amber-700">
                        {e.last_verified_at
                          ? `Zuletzt geprüft: ${formatDate(e.last_verified_at)}`
                          : "Nie geprüft"}
                      </p>
                    </div>
                    <div className="flex shrink-0 items-center gap-3">
                      <Link
                        href={`/events/${e.id}`}
                        className="text-sm font-medium text-blue-600 hover:underline"
                      >
                        Bearbeiten
                      </Link>
                      <ConfirmButton
                        action={markEventVerified.bind(null, e.id)}
                        confirmMessage="Quelle wurde geprüft, als aktuell markieren?"
                        label="Als geprüft markieren"
                        pendingLabel="…"
                        className="text-sm font-medium text-emerald-700 hover:text-emerald-900 disabled:opacity-50"
                      />
                    </div>
                  </div>
                ))
              ) : (
                <div className="rounded-lg border border-dashed border-neutral-300 bg-white px-4 py-8 text-center text-sm text-neutral-400">
                  Keine veralteten Events — alles innerhalb von {STALE_AFTER_DAYS} Tagen geprüft.
                </div>
              )}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
