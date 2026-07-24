// Automatische Bilder-Anreicherung für Venues/Personen/Ensembles/Festivals
// ohne eigenes Foto, plus Cover-Bilder für Events ohne image_urls — auf
// expliziten Nutzerwunsch ("Bilder automatisch hinzufügen"), analog zum
// bestehenden resolve-entity-candidates-Batch-Muster (fester Aufruf,
// begrenztes Limit pro Lauf, manuell auslösbar über einen Admin-Button).
//
// Venues/Personen/Ensembles/Festivals: Wikimedia-Commons-Suche (siehe
// _shared/wikimediaCommons.ts) nach einem Bild mit erkennbar freier Lizenz.
// Ein Treffer landet als NEUE Zeile in images mit needs_review=true,
// license_status='unknown' — NIE automatisch freigegeben (siehe
// 20260819000003_images_and_tags.sql), das hier ist reine Vorauswahl. Die
// eigentliche Übernahme ins photo_url-Feld passiert erst, wenn eine
// Redakteurin das Bild im Media-Review (/media) bestätigt (siehe
// admin/src/app/(dashboard)/media/actions.ts).
//
// Events: eine frisch gesuchte "Titelbild"-Aufnahme für ein einzelnes,
// noch gar nicht stattgefundenes Konzert gibt es naturgemäß nicht — dafür
// wird stattdessen das (bereits redaktionell geprüfte) Venue-Foto
// übernommen, sofern vorhanden. Das ist keine neue externe Quelle, sondern
// eine Referenz auf ein Bild, dessen Lizenz schon geklärt ist, deshalb ohne
// zusätzlichen Review-Schritt direkt in events.image_urls geschrieben.
//
// Aufruf: POST { limit?: number } — verarbeitet bis zu `limit` (Default 8)
// Entitäten PRO KATEGORIE (venues/persons/ensembles/festivals) und beliebig
// viele Events (reine DB-Kopie, kein externer API-Call, kein Limit nötig).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { searchCommonsImage } from "../_shared/wikimediaCommons.ts";
import { logSystemAction } from "../_shared/systemLog.ts";

const DEFAULT_LIMIT = 8;

interface EntityKind {
  table: string;
  originType: "venue" | "person" | "ensemble" | "festival";
  nameColumn: string;
  /** Zusätzlicher Suchkontext, um Namensgleichheiten mit anderen Städten/
   * Personen zu vermeiden (z.B. "Isarphilharmonie" -> "Isarphilharmonie
   * München", ein reiner Personenname bleibt dagegen ambiger genug, dass
   * ein Zusatz eher schadet als hilft). */
  queryContext?: string;
}

const ENTITY_KINDS: EntityKind[] = [
  // Nur "München" als Zusatz, kein Venue-/Genre-Wort — Commons' Volltextsuche
  // matcht gegen Dateititel/Kategorien, ein zusätzliches Wort wie
  // "Konzertsaal" schlägt bei Venues, die selbst keine Konzertsäle sind
  // (Kirchen, Museen), fehl und lieferte in der Praxis 0 statt einige
  // Treffer (z.B. "Alte Pinakothek München Konzertsaal" -> kein einziger
  // Treffer, "Alte Pinakothek" allein -> mehrere CC-BY-Treffer).
  { table: "venues", originType: "venue", nameColumn: "name", queryContext: "München" },
  { table: "persons", originType: "person", nameColumn: "full_name" },
  { table: "ensembles", originType: "ensemble", nameColumn: "name" },
  { table: "festivals", originType: "festival", nameColumn: "name", queryContext: "München" },
];

Deno.serve(async (req) => {
  let body: { limit?: unknown };
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const limit = typeof body.limit === "number" && body.limit > 0 ? body.limit : DEFAULT_LIMIT;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const perKind: Record<string, { found: number; queued: number; errors: string[] }> = {};
  for (const kind of ENTITY_KINDS) {
    perKind[kind.table] = await enrichEntityKind(supabase, kind, limit);
  }
  const eventResult = await enrichEventCovers(supabase);

  const totalQueued = Object.values(perKind).reduce((sum, r) => sum + r.queued, 0);
  if (totalQueued > 0 || eventResult.updated > 0) {
    await logSystemAction(supabase, "images", null, "auto_enrichment_batch", {
      perKind,
      events: eventResult,
    });
  }

  return jsonResponse({ ...perKind, events: eventResult });
});

async function enrichEntityKind(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  kind: EntityKind,
  limit: number,
): Promise<{ found: number; queued: number; errors: string[] }> {
  const { data: rows, error } = await supabase
    .from(kind.table)
    .select(`id, ${kind.nameColumn}`)
    .is("photo_url", null)
    .limit(limit);

  if (error) {
    return { found: 0, queued: 0, errors: [`${kind.table}: Laden fehlgeschlagen — ${error.message}`] };
  }

  const list = (rows ?? []) as Array<Record<string, unknown>>;
  let queued = 0;
  const errors: string[] = [];

  for (const row of list) {
    const id = row.id as string;
    const name = row[kind.nameColumn] as string;
    if (!name?.trim()) continue;

    try {
      // Schon eine images-Zeile (egal welchen Status) für diese Entität? —
      // dann läuft schon eine Prüfung/Entscheidung, keine zweite Suche.
      const { data: existing } = await supabase
        .from("images")
        .select("id")
        .eq("origin_type", kind.originType)
        .eq("origin_id", id)
        .maybeSingle();
      if (existing) continue;

      const query = kind.queryContext ? `${name} ${kind.queryContext}` : name;
      const candidate = await searchCommonsImage(query);
      if (!candidate) continue;

      const { error: insertError } = await supabase.from("images").insert({
        source_url: candidate.url,
        origin_type: kind.originType,
        origin_id: id,
        photographer: candidate.artist,
        license_notes: `Wikimedia Commons: ${candidate.license}` +
          (candidate.attributionRequired ? " (Namensnennung erforderlich)" : "") +
          ` — ${candidate.pageUrl}`,
      });
      if (insertError) {
        errors.push(`${kind.table} "${name}": Insert fehlgeschlagen — ${insertError.message}`);
        continue;
      }
      queued++;
    } catch (err) {
      errors.push(`${kind.table} "${name}": ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  return { found: list.length, queued, errors: errors.slice(0, 10) };
}

/** Übernimmt das Venue-Foto als Event-Titelbild für bevorstehende Events
 * ohne eigenes Bild — dieselbe Kriterien (aktiv, bevorstehend) wie die
 * Datenqualitäts-Review-Seite im Admin-Dashboard. */
async function enrichEventCovers(
  // deno-lint-ignore no-explicit-any
  supabase: any,
): Promise<{ found: number; updated: number; errors: string[] }> {
  const { data: events, error } = await supabase
    .from("events")
    .select("id, image_urls, venues(photo_url)")
    .in("status", ["scheduled", "sold_out", "postponed"])
    .gte("start_datetime", new Date().toISOString());

  if (error) {
    return { found: 0, updated: 0, errors: [`events: Laden fehlgeschlagen — ${error.message}`] };
  }

  const missingImages = (events ?? []).filter(
    (e: { image_urls: string[] | null }) => !e.image_urls || e.image_urls.length === 0,
  );

  let updated = 0;
  const errors: string[] = [];
  for (const event of missingImages) {
    const venue = Array.isArray(event.venues) ? event.venues[0] : event.venues;
    const venuePhoto = venue?.photo_url;
    if (!venuePhoto) continue;

    const { error: updateError } = await supabase
      .from("events")
      .update({ image_urls: [venuePhoto], updated_at: new Date().toISOString() })
      .eq("id", event.id);
    if (updateError) {
      errors.push(`event ${event.id}: ${updateError.message}`);
      continue;
    }
    updated++;
  }

  return { found: missingImages.length, updated, errors: errors.slice(0, 10) };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
