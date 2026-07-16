// iCal (.ics) connector — normalizes VEVENT components from an iCalendar feed
// into RawEvent[]. Uses node-ical (via npm: specifier) instead of hand-rolling
// RFC 5545 parsing, since line-folding, escaping, TZID handling, and RRULE
// syntax all have many edge cases.
//
// UNCERTAIN (flagged per task instructions — cannot run/type-check under Deno
// in this environment): node-ical's default export shape when imported via
// "npm:node-ical@x.y.z" under Deno's npm-compat layer. The package is CJS
// (`module.exports = { parseICS, sync, async, ... }`); a default import should
// bind to that whole object, matching `ical.parseICS(...)` below, but this is
// not verified against an actual Deno runtime here.
import ical from "npm:node-ical@0.18.0";
import type { ParseResult, RawEvent } from "../types.ts";

/**
 * Extracts a plain string from an ical.js/node-ical property value.
 *
 * UNCERTAIN: most TEXT properties (SUMMARY, DESCRIPTION, LOCATION, URL) come
 * back from node-ical as plain strings, but properties carrying extra
 * parameters (e.g. SUMMARY;LANGUAGE=de:..., URL with VALUE=URI params) can
 * occasionally surface as `{ val: string, params: {...} }` objects instead.
 * This helper accepts either shape defensively rather than assuming one.
 */
function textValue(v: unknown): string | null {
  if (v == null) return null;
  if (typeof v === "string") {
    const trimmed = v.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  if (typeof v === "object") {
    const val = (v as { val?: unknown }).val;
    if (typeof val === "string") {
      const trimmed = val.trim();
      return trimmed.length > 0 ? trimmed : null;
    }
  }
  return null;
}

/**
 * Heuristically splits an iCal LOCATION free-text value into a venue name and
 * a remaining address. LOCATION is commonly formatted as
 * "Venue Name, Street, ZIP City" — if it contains at least one comma we treat
 * the first segment as the venue name and the rest as the address; otherwise
 * the whole string is treated as the venue name.
 */
function splitLocation(
  location: string | null,
): { venueName: string | null; venueAddress: string | null } {
  if (!location) return { venueName: null, venueAddress: null };

  const parts = location
    .split(",")
    .map((p) => p.trim())
    .filter((p) => p.length > 0);

  if (parts.length <= 1) {
    return { venueName: location, venueAddress: null };
  }

  return {
    venueName: parts[0],
    venueAddress: parts.slice(1).join(", "),
  };
}

function toIsoOrNull(v: unknown): string | null {
  if (v instanceof Date && !isNaN(v.getTime())) {
    return v.toISOString();
  }
  return null;
}

export function parseIcal(content: string): ParseResult {
  const events: RawEvent[] = [];
  const errors: string[] = [];

  // deno-lint-ignore no-explicit-any
  let data: Record<string, any>;
  try {
    // Synchronous string-parsing entrypoint — we already have the fetched
    // .ics content in memory, not a file path or URL, so parseICS (not
    // sync.parseFile / async.fromURL) is the right entrypoint.
    data = ical.parseICS(content);
  } catch (err) {
    errors.push(
      `failed to parse iCal content: ${
        err instanceof Error ? err.message : String(err)
      }`,
    );
    return { events, errors };
  }

  if (!data || typeof data !== "object") {
    errors.push("iCal parse returned no data");
    return { events, errors };
  }

  for (const [key, item] of Object.entries(data)) {
    if (!item || typeof item !== "object") continue;

    // deno-lint-ignore no-explicit-any
    const ev = item as Record<string, any>;
    if (ev.type !== "VEVENT") continue;

    const uid = textValue(ev.uid) ?? (key || null);
    const label = uid ?? "(unknown uid)";

    try {
      const title = textValue(ev.summary);
      if (!title) {
        errors.push(`event ${label}: missing summary/title, skipped`);
        continue;
      }

      const startDateTime = toIsoOrNull(ev.start);
      if (!startDateTime) {
        errors.push(`event ${label} ("${title}"): missing or invalid start date, skipped`);
        continue;
      }

      const endDateTime = toIsoOrNull(ev.end);

      const description = textValue(ev.description);
      const location = textValue(ev.location);
      const { venueName, venueAddress } = splitLocation(location);
      const url = textValue(ev.url);

      // Recurring events: node-ical does NOT expand RRULE occurrences into
      // separate dictionary entries. The master VEVENT instead gets an
      // `rrule` property (an RRule instance from the `rrule` npm package),
      // and date-specific overrides/exceptions (RECURRENCE-ID) may appear
      // under an `ev.recurrences` map keyed by ISO date string.
      // UNCERTAIN: exact shape of `ev.recurrences` — not verified here.
      // Full expansion is out of scope; we emit only the base occurrence
      // (ev.start/ev.end as parsed above) and flag it so downstream review
      // knows this event recurs beyond the single occurrence captured here.
      if (ev.rrule) {
        errors.push(`recurring event ${label}: only base occurrence extracted`);
      }

      const rawEvent: RawEvent = {
        externalId: uid,
        title,
        description,
        startDateTime,
        endDateTime,
        venueName,
        venueAddress,
        url,
        imageUrl: null,
        priceMin: null,
        priceMax: null,
        isFree: null,
      };

      events.push(rawEvent);
    } catch (err) {
      errors.push(
        `event ${label}: unexpected error during parsing — ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }
  }

  return { events, errors };
}
