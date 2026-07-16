// Schreiblogik für den Ingestion-Worker: pro RawEvent entscheiden, ob es
// ein bereits bekanntes Event ist (exaktes (source_id, external_id)-Match
// oder Fuzzy-Match via matching.ts), aktualisiert werden muss, ein
// Duplicate-Candidate ist, oder komplett neu angelegt wird. Siehe
// docs/06-mvp-plan.md "Ingestion-Pipeline (Basis)" für den Gesamtkontext.

import { findEventMatch, resolveVenue } from "./matching.ts";
import type { RawEvent } from "./types.ts";

interface SourceRow {
  id: string;
  venue_id: string | null;
}

export type WriteOutcome =
  | { outcome: "unchanged" }
  | { outcome: "updated" }
  | { outcome: "created" }
  | { outcome: "flagged" }
  | { outcome: "error"; error: string };

const DIFFABLE_FIELDS = [
  "title",
  "description_de",
  "start_datetime",
  "end_datetime",
  "price_min",
  "price_max",
  "is_free",
  "website_url",
  "image_urls",
] as const;

/**
 * Per-RawEvent decision tree:
 *  1. Resolve venue (source.venue_id, or fuzzy find_matching_venue()).
 *  2. Exact match on (source_id, external_id) if raw.externalId is set —
 *     authoritative, idempotent re-ingestion of the SAME source.
 *  3. Otherwise fuzzy title+venue+time match — catches the SAME real-world
 *     event reported by a DIFFERENT source (or one with no external id).
 *     High confidence (>=0.7) updates in place; moderate confidence
 *     (0.35-0.7) creates a draft and flags it for admin review instead of
 *     silently merging or silently duplicating.
 *  4. No match at all -> brand-new draft event.
 * Never throws — every failure mode returns {outcome: 'error', error}.
 */
export async function upsertRawEvent(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  source: SourceRow,
  raw: RawEvent,
): Promise<WriteOutcome> {
  try {
    const venueResult = await resolveVenue(supabase, source, raw);
    if ("error" in venueResult) {
      return { outcome: "error", error: venueResult.error };
    }
    const venueId = venueResult.venueId;

    const contentHash = await computeContentHash(raw);
    const nowIso = new Date().toISOString();

    if (raw.externalId) {
      const { data: existing, error } = await supabase
        .from("events")
        .select(
          "id, title, description_de, start_datetime, end_datetime, price_min, price_max, is_free, website_url, image_urls, content_hash",
        )
        .eq("source_id", source.id)
        .eq("external_id", raw.externalId)
        .maybeSingle();

      if (error) {
        return { outcome: "error", error: `lookup by external_id failed: ${error.message}` };
      }

      if (existing) {
        if (existing.content_hash === contentHash) {
          const { error: touchError } = await supabase
            .from("events")
            .update({ last_verified_at: nowIso })
            .eq("id", existing.id);
          if (touchError) {
            return { outcome: "error", error: `failed to refresh last_verified_at: ${touchError.message}` };
          }
          return { outcome: "unchanged" };
        }
        return await applyUpdate(supabase, existing, raw, contentHash, nowIso, source.id);
      }
      // No row for this (source_id, external_id) yet — first time this
      // source has reported it. Still worth a fuzzy check: it may already
      // be tracked from a DIFFERENT source (or manually, with no source_id
      // at all) before we fall back to creating a brand-new event.
    }

    const match = await findEventMatch(supabase, raw.title, venueId, raw.startDateTime);

    if (match && match.similarity >= 0.7) {
      const { data: existing, error } = await supabase
        .from("events")
        .select(
          "id, title, description_de, start_datetime, end_datetime, price_min, price_max, is_free, website_url, image_urls, content_hash",
        )
        .eq("id", match.id)
        .maybeSingle();

      if (error || !existing) {
        return {
          outcome: "error",
          error: `failed to load matched event ${match.id}: ${error?.message ?? "not found"}`,
        };
      }

      const outcome = await applyUpdate(supabase, existing, raw, contentHash, nowIso, source.id);
      if (outcome.outcome !== "error") {
        // Backfill so future runs of THIS source hit the fast exact-match
        // path above. Guarded on source_id being null so we never steal
        // ownership from a different source that's already tracking it.
        await supabase
          .from("events")
          .update({ source_id: source.id, external_id: raw.externalId })
          .eq("id", existing.id)
          .is("source_id", null);
      }
      return outcome;
    }

    const slug = await generateUniqueSlug(supabase, raw.title);
    const { data: created, error: createError } = await supabase
      .from("events")
      .insert({
        slug,
        title: raw.title,
        description_de: raw.description,
        start_datetime: raw.startDateTime,
        end_datetime: raw.endDateTime,
        venue_id: venueId,
        price_min: raw.priceMin,
        price_max: raw.priceMax,
        is_free: raw.isFree ?? false,
        website_url: raw.url,
        image_urls: raw.imageUrl ? [raw.imageUrl] : [],
        status: "draft",
        source_id: source.id,
        external_id: raw.externalId,
        content_hash: contentHash,
        last_verified_at: nowIso,
      })
      .select("id")
      .single();

    if (createError || !created) {
      return { outcome: "error", error: `failed to create event: ${createError?.message ?? "unknown"}` };
    }

    if (match) {
      const { error: dupError } = await supabase.from("duplicate_candidates").insert({
        event_a_id: match.id,
        event_b_id: created.id,
        similarity_score: match.similarity,
        status: "pending",
      });
      if (dupError) {
        return {
          outcome: "error",
          error: `created event ${created.id} but failed to flag as duplicate candidate: ${dupError.message}`,
        };
      }
      return { outcome: "flagged" };
    }

    return { outcome: "created" };
  } catch (err) {
    return { outcome: "error", error: err instanceof Error ? err.message : String(err) };
  }
}

async function applyUpdate(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  // deno-lint-ignore no-explicit-any
  existing: Record<string, any>,
  raw: RawEvent,
  contentHash: string,
  nowIso: string,
  sourceId: string,
): Promise<WriteOutcome> {
  const updates = buildUpdatePayload(raw);

  if (raw.imageUrl) {
    const currentImages: string[] = Array.isArray(existing.image_urls) ? existing.image_urls : [];
    if (!currentImages.includes(raw.imageUrl)) {
      updates.image_urls = [...currentImages, raw.imageUrl];
    }
  }

  const { changedFields, oldValues, newValues } = diffFields(existing, updates);

  const { error: updateError } = await supabase
    .from("events")
    .update({ ...updates, content_hash: contentHash, last_verified_at: nowIso })
    .eq("id", existing.id);

  if (updateError) {
    return { outcome: "error", error: `failed to update event ${existing.id}: ${updateError.message}` };
  }

  if (changedFields.length > 0) {
    const { error: logError } = await supabase.from("event_change_log").insert({
      event_id: existing.id,
      changed_fields: changedFields,
      old_values: oldValues,
      new_values: newValues,
      changed_by: `ingestion:${sourceId}`,
    });
    if (logError) {
      // The event itself was already updated successfully — a failed audit
      // log write shouldn't be reported as an outcome error (nothing about
      // the event data is wrong), just surfaced for visibility.
      console.error(`event ${existing.id} updated but change-log insert failed: ${logError.message}`);
    }
  }

  return { outcome: "updated" };
}

/** Only includes keys the source actually provided a non-null value for —
 * a source that doesn't know a field (e.g. RSS has no price) must never
 * overwrite a previously-known value from a richer source with null. */
function buildUpdatePayload(raw: RawEvent): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    title: raw.title,
    start_datetime: raw.startDateTime,
  };
  if (raw.description !== null) payload.description_de = raw.description;
  if (raw.endDateTime !== null) payload.end_datetime = raw.endDateTime;
  if (raw.priceMin !== null) payload.price_min = raw.priceMin;
  if (raw.priceMax !== null) payload.price_max = raw.priceMax;
  if (raw.isFree !== null) payload.is_free = raw.isFree;
  if (raw.url !== null) payload.website_url = raw.url;
  return payload;
}

function diffFields(
  existing: Record<string, unknown>,
  updates: Record<string, unknown>,
): { changedFields: string[]; oldValues: Record<string, unknown>; newValues: Record<string, unknown> } {
  const changedFields: string[] = [];
  const oldValues: Record<string, unknown> = {};
  const newValues: Record<string, unknown> = {};

  for (const field of DIFFABLE_FIELDS) {
    if (!(field in updates)) continue;
    const oldVal = existing[field] ?? null;
    const newVal = updates[field] ?? null;
    if (!valuesEqual(oldVal, newVal)) {
      changedFields.push(field);
      oldValues[field] = oldVal;
      newValues[field] = newVal;
    }
  }

  return { changedFields, oldValues, newValues };
}

function valuesEqual(a: unknown, b: unknown): boolean {
  if (typeof a === "number" && typeof b === "number") {
    return Math.abs(a - b) < 0.001;
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    return JSON.stringify(a) === JSON.stringify(b);
  }
  return a === b;
}

/** Deterministic SHA-256 over the mutable fields — unchanged hash means an
 * exact-match re-fetch is a no-op ping, not a real update. */
async function computeContentHash(raw: RawEvent): Promise<string> {
  const canonical = {
    title: raw.title,
    description: raw.description,
    startDateTime: raw.startDateTime,
    endDateTime: raw.endDateTime,
    priceMin: raw.priceMin,
    priceMax: raw.priceMax,
    isFree: raw.isFree,
    url: raw.url,
    imageUrl: raw.imageUrl,
  };
  const bytes = new TextEncoder().encode(JSON.stringify(canonical));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return toHex(digest);
}

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function slugify(title: string): string {
  const umlauts: Record<string, string> = {
    ä: "ae",
    ö: "oe",
    ü: "ue",
    ß: "ss",
    Ä: "ae",
    Ö: "oe",
    Ü: "ue",
  };
  let s = title;
  for (const [from, to] of Object.entries(umlauts)) {
    s = s.split(from).join(to);
  }
  s = s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80)
    .replace(/-+$/g, "");
  return s || "veranstaltung";
}

async function generateUniqueSlug(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  title: string,
): Promise<string> {
  const base = slugify(title);
  for (let attempt = 0; attempt < 20; attempt++) {
    const candidate = attempt === 0 ? base : `${base}-${attempt + 1}`;
    const { data } = await supabase.from("events").select("id").eq("slug", candidate).maybeSingle();
    if (!data) return candidate;
  }
  return `${base}-${Date.now()}`;
}
