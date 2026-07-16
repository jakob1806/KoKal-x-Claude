// Venue-/Event-Matching für den Ingestion-Worker. Wrappt die zwei
// pg_trgm-basierten RPCs aus der Migration 20260802000001.

import type { RawEvent } from "./types.ts";

interface SourceRow {
  id: string;
  venue_id: string | null;
}

export async function resolveVenue(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  source: SourceRow,
  raw: RawEvent,
): Promise<{ venueId: string } | { error: string }> {
  if (source.venue_id) {
    return { venueId: source.venue_id };
  }

  if (!raw.venueName) {
    return { error: "no venue_id on source and RawEvent has no venueName to match against" };
  }

  const { data, error } = await supabase.rpc("find_matching_venue", {
    p_name: raw.venueName,
  });

  if (error) {
    return { error: `find_matching_venue RPC failed: ${error.message}` };
  }

  const best = (data ?? [])[0];
  if (!best || best.similarity < 0.5) {
    return { error: `no venue match for '${raw.venueName}'` };
  }

  return { venueId: best.id };
}

export async function findEventMatch(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  title: string,
  venueId: string,
  startDateTime: string,
): Promise<{ id: string; similarity: number } | null> {
  const { data, error } = await supabase.rpc("find_matching_event", {
    p_title: title,
    p_venue_id: venueId,
    p_start_datetime: startDateTime,
  });

  if (error) {
    // Matching is best-effort — a failed lookup should fall through to
    // "no match" (create as new) rather than abort the whole event.
    console.error(`find_matching_event RPC failed: ${error.message}`);
    return null;
  }

  const best = (data ?? [])[0];
  return best ? { id: best.id, similarity: best.similarity } : null;
}
