// RSS/Atom-Connector für ingest-source.
//
// Generisches RSS/Atom hat keine strukturierten Event-Felder (kein
// Start-/Endzeitpunkt, kein Venue, kein Preis) — pubDate ist der
// Veröffentlichungszeitpunkt des Feed-Eintrags, NICHT der Termin der
// Veranstaltung. Wir extrahieren Datum/Venue daher per Best-Effort aus dem
// Freitext (Titel + Beschreibung/Content). Kann kein Datum mit
// ausreichender Sicherheit erkannt werden, wird der Eintrag übersprungen
// und als Fehler gemeldet — ein erfundenes/falsches Datum wäre schlimmer
// als ein fehlender Event.

// Uncertain: rss-parser's package.json only declares an `exports` field for
// modern versions, and its `export = Parser` CJS typing under Deno's npm:
// node-compat layer is something I can't type-check here — if the default
// import doesn't resolve, try `import { Parser } from "npm:rss-parser@3"`
// as a fallback.
import Parser from "npm:rss-parser@3";
import type { ParseResult, RawEvent } from "../types.ts";

export async function parseRss(content: string): Promise<ParseResult> {
  const errors: string[] = [];
  const events: RawEvent[] = [];

  const parser = new Parser();
  let feed;
  try {
    // rss-parser's documented API for parsing an already-fetched string
    // (as opposed to parseURL, which fetches itself) is parseString().
    feed = await parser.parseString(content);
  } catch (err) {
    errors.push(
      `failed to parse RSS/Atom feed: ${err instanceof Error ? err.message : String(err)}`,
    );
    return { events, errors };
  }

  const items = feed?.items ?? [];

  for (const item of items) {
    const rawTitle = item.title;
    if (typeof rawTitle !== "string" || rawTitle.trim().length === 0) {
      errors.push("RSS item missing a title, skipped");
      continue;
    }
    const title = rawTitle.trim();

    // Uncertain: rss-parser's default field mapping for the description —
    // `contentSnippet` (plain-text) is populated from `content` when
    // present; `content` itself is sourced from <description>/<summary> or
    // aliased from <content:encoded> depending on feed shape. Falling back
    // through both covers RSS and Atom without needing custom field config.
    const description: string | null = item.contentSnippet ?? item.content ??
      null;

    const url: string | null = item.link ?? null;
    const externalId: string | null = item.guid ?? item.link ?? null;

    const searchText = stripHtml(
      `${title} ${description ?? ""}`,
    );

    const dateMatch = extractDate(searchText);
    if (!dateMatch) {
      errors.push(`no parseable event date in RSS item: ${title}`);
      continue;
    }

    let hour = dateMatch.hour;
    let minute = dateMatch.minute;
    if (hour === null || minute === null) {
      const time = extractTime(searchText);
      if (time) {
        hour = time.hour;
        minute = time.minute;
      } else {
        // No time found anywhere in the free text — default to midnight
        // rather than guessing a plausible-looking time. The date itself
        // is the higher-confidence part of the extraction.
        hour = 0;
        minute = 0;
      }
    }

    const startDateTime = toIsoWithBerlinOffset(
      dateMatch.year,
      dateMatch.month,
      dateMatch.day,
      hour,
      minute,
    );

    const venueName = extractVenueHint(searchText);

    const rawEvent: RawEvent = {
      externalId,
      title,
      description,
      startDateTime,
      endDateTime: null,
      venueName,
      venueAddress: null,
      url,
      imageUrl: null,
      priceMin: null,
      priceMax: null,
      isFree: null,
    };
    events.push(rawEvent);
  }

  return { events, errors };
}

// ---------------------------------------------------------------------------
// Date/time extraction
// ---------------------------------------------------------------------------

interface DateMatch {
  year: number;
  month: number; // 1-12
  day: number;
  hour: number | null;
  minute: number | null;
}

const GERMAN_MONTHS: Record<string, number> = {
  "januar": 1,
  "februar": 2,
  "märz": 3,
  "maerz": 3,
  "april": 4,
  "mai": 5,
  "juni": 6,
  "juli": 7,
  "august": 8,
  "september": 9,
  "oktober": 10,
  "november": 11,
  "dezember": 12,
};

/**
 * Tries a small set of date patterns in order of decreasing confidence:
 * ISO-ish (2026-03-12[, T20:00]), German long form (12. März 2026), then
 * German numeric (12.03.2026). Returns null if none match with a valid
 * calendar date — a syntactically-matching but impossible date (e.g.
 * 31.02.2026) is treated as no match rather than silently clamped.
 */
function extractDate(text: string): DateMatch | null {
  return tryIsoDate(text) ?? tryGermanLongDate(text) ?? tryGermanNumericDate(text);
}

function tryIsoDate(text: string): DateMatch | null {
  const m = text.match(/\b(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?/);
  if (!m) return null;
  const year = parseInt(m[1], 10);
  const month = parseInt(m[2], 10);
  const day = parseInt(m[3], 10);
  if (!isValidDate(year, month, day)) return null;
  const hour = m[4] !== undefined ? parseInt(m[4], 10) : null;
  const minute = m[5] !== undefined ? parseInt(m[5], 10) : null;
  return { year, month, day, hour, minute };
}

function tryGermanLongDate(text: string): DateMatch | null {
  const m = text.match(
    /\b(\d{1,2})\.\s*(Januar|Februar|März|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember)\s*(\d{4})\b/i,
  );
  if (!m) return null;
  const day = parseInt(m[1], 10);
  const month = GERMAN_MONTHS[m[2].toLowerCase()];
  const year = parseInt(m[3], 10);
  if (!month || !isValidDate(year, month, day)) return null;
  return { year, month, day, hour: null, minute: null };
}

function tryGermanNumericDate(text: string): DateMatch | null {
  const m = text.match(/\b(\d{1,2})\.(\d{1,2})\.(\d{2,4})\b/);
  if (!m) return null;
  const day = parseInt(m[1], 10);
  const month = parseInt(m[2], 10);
  let year = parseInt(m[3], 10);
  if (year < 100) year += 2000; // 2-digit year: assume 2000s
  if (!isValidDate(year, month, day)) return null;
  return { year, month, day, hour: null, minute: null };
}

function isValidDate(year: number, month: number, day: number): boolean {
  if (year < 2000 || year > 2100) return false;
  if (month < 1 || month > 12) return false;
  if (day < 1 || day > 31) return false;
  const d = new Date(Date.UTC(year, month - 1, day));
  return (
    d.getUTCFullYear() === year &&
    d.getUTCMonth() === month - 1 &&
    d.getUTCDate() === day
  );
}

function extractTime(text: string): { hour: number; minute: number } | null {
  let m = text.match(/\b(\d{1,2}):(\d{2})\s*(?:Uhr)?\b/);
  if (m) {
    const hour = parseInt(m[1], 10);
    const minute = parseInt(m[2], 10);
    if (hour <= 23 && minute <= 59) return { hour, minute };
  }
  m = text.match(/\b(\d{1,2})\s*Uhr\b/i);
  if (m) {
    const hour = parseInt(m[1], 10);
    if (hour <= 23) return { hour, minute: 0 };
  }
  return null;
}

/**
 * Builds an ISO 8601 string with an explicit UTC offset for the given
 * wall-clock date/time, assuming Europe/Berlin local time (reasonable given
 * this pipeline only ingests German event sources). Applies the standard EU
 * DST rule (CEST from the last Sunday of March 01:00 UTC through the last
 * Sunday of October 01:00 UTC) rather than hardcoding +01:00/+02:00.
 *
 * Uncertain: this hand-rolls the EU DST boundary instead of using a
 * timezone-aware API — Deno's Intl/ICU build does support IANA timezones,
 * but resolving an offset string from Intl.DateTimeFormat reliably (across
 * Deno versions) is more moving parts than this warrants; the EU rule is
 * fixed by law and simple to compute directly.
 */
function toIsoWithBerlinOffset(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
): string {
  const isSummer = isBerlinSummerTime(year, month, day, hour);
  const offset = isSummer ? "+02:00" : "+01:00";
  return `${year.toString().padStart(4, "0")}-${pad(month)}-${pad(day)}T${
    pad(hour)
  }:${pad(minute)}:00${offset}`;
}

function isBerlinSummerTime(
  year: number,
  month: number,
  day: number,
  hour: number,
): boolean {
  // Naive UTC ms treating the wall-clock components as if they were UTC —
  // only used to compare against the DST boundary dates computed the same
  // (naive) way, so the ~1-2h offset ambiguity right at the boundary is the
  // only inaccuracy, which is an acceptable edge case here.
  const naiveMs = Date.UTC(year, month - 1, day, hour);
  const dstStart = lastSundayUtcMs(year, 2 /* March, 0-indexed */, 1);
  const dstEnd = lastSundayUtcMs(year, 9 /* October, 0-indexed */, 1);
  return naiveMs >= dstStart && naiveMs < dstEnd;
}

/** UTC ms of the last Sunday of the given (0-indexed) month, at the given hour. */
function lastSundayUtcMs(year: number, monthIndex0: number, hour: number): number {
  const lastDayOfMonth = new Date(Date.UTC(year, monthIndex0 + 1, 0)).getUTCDate();
  const lastDate = new Date(Date.UTC(year, monthIndex0, lastDayOfMonth));
  const dow = lastDate.getUTCDay(); // 0 = Sunday
  const lastSundayDate = lastDayOfMonth - dow;
  return Date.UTC(year, monthIndex0, lastSundayDate, hour);
}

function pad(n: number): string {
  return n.toString().padStart(2, "0");
}

// ---------------------------------------------------------------------------
// Venue hint extraction
// ---------------------------------------------------------------------------

/**
 * Best-effort venue name guess from free text — looks for a capitalized
 * phrase following "im"/"in der"/"in den"/"@". This is only a hint fed to
 * find_matching_venue() downstream, so a missed or imprecise match is fine;
 * unlike the date, an imperfect venue guess doesn't corrupt the event, it
 * just fails to match and falls through to manual review.
 */
function extractVenueHint(text: string): string | null {
  const patterns = [
    /\bim\s+([A-ZÄÖÜ][\wäöüÄÖÜß.\-\s]{1,60}?)(?=[,.\n;]|$)/,
    /\bin der\s+([A-ZÄÖÜ][\wäöüÄÖÜß.\-\s]{1,60}?)(?=[,.\n;]|$)/,
    /\bin den\s+([A-ZÄÖÜ][\wäöüÄÖÜß.\-\s]{1,60}?)(?=[,.\n;]|$)/,
    /@\s*([A-ZÄÖÜ][\wäöüÄÖÜß.\-\s]{1,60}?)(?=[,.\n;]|$)/,
  ];
  for (const pattern of patterns) {
    const m = text.match(pattern);
    if (m && m[1] && m[1].trim().length > 0) {
      return m[1].trim();
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Text helpers
// ---------------------------------------------------------------------------

/** Strips HTML tags and decodes the handful of entities common in feed text. */
function stripHtml(html: string): string {
  return html
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/\s+/g, " ")
    .trim();
}
