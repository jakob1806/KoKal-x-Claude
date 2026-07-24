import { ConfirmButton } from "@/components/confirm-button";
import { createClient } from "@/lib/supabase/server";
import { confirmImageFree, confirmImageLicensed, rejectImage } from "./actions";
import { EnrichImagesButton } from "./enrich-images-button";

export const dynamic = "force-dynamic";

const ORIGIN_LABEL: Record<string, string> = {
  event: "Event",
  venue: "Venue",
  ensemble: "Ensemble",
  person: "Person",
  organizer: "Institution",
  festival: "Festival",
};

interface ImageRow {
  id: string;
  source_url: string;
  origin_type: string;
  origin_id: string;
  photographer: string | null;
  copyright_notice: string | null;
  license_notes: string | null;
  imported_at: string;
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("de-DE", { dateStyle: "medium", timeStyle: "short" });
}

export default async function MediaPage() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("images")
    .select("id, source_url, origin_type, origin_id, photographer, copyright_notice, license_notes, imported_at")
    .eq("needs_review", true)
    .order("imported_at", { ascending: false })
    .returns<ImageRow[]>();

  return (
    <div className="p-8">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Bilder — Lizenz-Review</h1>
          <p className="mt-1 max-w-xl text-sm text-neutral-500">
            Automatisch importierte/gefundene Bilder gelten nie automatisch als frei nutzbar — jedes Bild
            braucht eine redaktionelle Freigabe. Eine Freigabe (&bdquo;Frei nutzbar&rdquo;/&bdquo;Lizenziert&rdquo;) übernimmt
            das Bild direkt in das Foto-Feld der jeweiligen Venue/Person/Ensemble/Festival bzw. als
            Event-Titelbild.
          </p>
        </div>
        <EnrichImagesButton />
      </div>

      {error && <p className="mt-6 text-sm text-amber-700">Konnte Bilder nicht laden: {error.message}</p>}

      {!error && (
        <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {data?.length ? (
            data.map((image) => (
              <div key={image.id} className="overflow-hidden rounded-lg border border-neutral-200 bg-white">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={image.source_url} alt="" className="h-40 w-full object-cover bg-neutral-100" />
                <div className="p-3">
                  <p className="text-xs text-neutral-400">
                    {ORIGIN_LABEL[image.origin_type] ?? image.origin_type} · {formatDate(image.imported_at)}
                  </p>
                  <a
                    href={image.source_url}
                    target="_blank"
                    rel="noreferrer"
                    className="mt-1 block truncate text-xs text-blue-600 hover:underline"
                  >
                    {image.source_url}
                  </a>
                  {image.photographer && (
                    <p className="mt-1 text-xs text-neutral-500">Foto: {image.photographer}</p>
                  )}
                  {image.copyright_notice && (
                    <p className="mt-1 text-xs text-neutral-500">© {image.copyright_notice}</p>
                  )}
                  {image.license_notes && (
                    <p className="mt-1 text-xs text-neutral-500">{image.license_notes}</p>
                  )}
                  <div className="mt-3 flex flex-wrap gap-3">
                    <ConfirmButton
                      action={confirmImageFree.bind(null, image.id)}
                      confirmMessage="Als frei nutzbar freigeben?"
                      label="Frei nutzbar"
                      pendingLabel="…"
                      className="text-xs font-medium text-emerald-700 hover:text-emerald-900 disabled:opacity-50"
                    />
                    <ConfirmButton
                      action={confirmImageLicensed.bind(null, image.id)}
                      confirmMessage="Als lizenziert (mit Quellenangabe) freigeben?"
                      label="Lizenziert"
                      pendingLabel="…"
                      className="text-xs font-medium text-amber-700 hover:text-amber-900 disabled:opacity-50"
                    />
                    <ConfirmButton
                      action={rejectImage.bind(null, image.id)}
                      confirmMessage="Bild ablehnen? Wird nie ausgespielt."
                      label="Ablehnen"
                      pendingLabel="…"
                      className="text-xs font-medium text-neutral-500 hover:text-neutral-900 disabled:opacity-50"
                    />
                  </div>
                </div>
              </div>
            ))
          ) : (
            <div className="col-span-full rounded-lg border border-dashed border-neutral-300 bg-white px-4 py-10 text-center text-sm text-neutral-400">
              Keine Bilder zur Prüfung.
            </div>
          )}
        </div>
      )}
    </div>
  );
}
