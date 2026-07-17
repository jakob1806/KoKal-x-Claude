// Generischer HTML-Scraping-Connector — für Quellen ohne Schema.org/iCal/RSS.
// sources.config (jsonb) hält die pro-Site-Selektoren, siehe ScrapeConfig
// unten; kein Code-Deploy nötig, um eine neue Scrape-Quelle anzubinden,
// nur eine neue config auf der sources-Zeile (config-getriebene
// "Selektoren" war schon in der ursprünglichen Schema-Doku für sources.config
// vorgesehen, siehe docs/02-database-schema.md §8).
//
// ACHTUNG (bewusste Produktentscheidung, nicht mein Vorschlag): docs/06-mvp-
// plan.md und docs/07-roadmap.md hatten Web-Scraping ausdrücklich auf "nach
// rechtlicher Einzelprüfung je Quelle" verschoben (Roadmap Phase 4). Dieser
// Connector existiert auf expliziten Wunsch, der diese Verschiebung bewusst
// umgeht — nicht meine Einschätzung, dass die rechtliche Prüfung entfallen
// kann. Als Mindest-Sorgfalt: robots.txt wird vor jedem Fetch geprüft (siehe
// index.ts), ein identifizierender User-Agent wird gesendet, keine hohe
// Crawl-Rate (ein Request pro Lauf).

import { parseHTML } from "npm:linkedom@0.18.4";
import type { ParseResult, RawEvent } from "../types.ts";

export interface ScrapeConfig {
  /** CSS-Selektor für ein einzelnes Event-"Karten"-Element. */
  itemSelector: string;
  /** Selektor relativ zum Item für den Titel. Falls "titleAttribute" fehlt,
   * wird standardmäßig nur der ERSTE direkte Text-Kindknoten genutzt (nicht
   * der ganze textContent) — Karten haben oft einen verschachtelten
   * Untertitel-<span>, der sonst mit reingezogen würde. Sites, deren Titel
   * selbst mehrzeilig ist (z.B. per <br> getrennte Komponisten-Liste ohne
   * eigenes Untertitel-Element) setzen titleFullText, um stattdessen den
   * kompletten textContent zu nehmen. */
  titleSelector: string;
  titleAttribute?: string;
  titleFullText?: boolean;
  /** Selektor für den Link zur Event-Detailseite (wird als externalId UND
   * als url verwendet — der Link ist auf solchen Seiten praktisch immer
   * pro Event eindeutig und stabil). */
  urlSelector: string;
  urlAttribute?: string; // default "href"
  /** Selektor für Datum/Uhrzeit. dateAttribute (z.B. "datetime" bei <time>)
   * wird bevorzugt, sonst wird der Text-Inhalt geparst (unterstützt
   * "YYYY-MM-DD" und "YYYY-MM-DD HH:MM", das hier beobachtete Format). */
  dateSelector: string;
  dateAttribute?: string;
  descriptionSelector?: string;
  imageSelector?: string;
  imageAttribute?: string; // default "src"
  /** Selektor für Tag-/Kategorie-Links relativ zum Item. */
  tagsSelector?: string;
  /** Nur Items behalten, bei denen mindestens ein Tag (kleingeschrieben)
   * eine dieser Zeichenketten enthält — z.B. ["musik", "klassik"]. Leer/
   * fehlend = keine Filterung. */
  includeIfTagContains?: string[];
  /** Regex (als String) gegen den href eines Tag-Links — der Text des
   * ERSTEN Tags, dessen href matcht, wird als venueName verwendet. Für
   * Seiten, die mehrere Säle/Räume unter einer Sammel-URL listen und den
   * Saal nur über das Link-Ziel eines Tags markieren (z.B. gasteig.de). */
  venueTagHrefPattern?: string;
  /** Fallback, falls kein Tag zu venueTagHrefPattern passt (z.B. die
   * gebäudeweite Location statt des einzelnen Saals). */
  venueTagFallbackHrefPattern?: string;
  /** Direkter Selektor für einen Venue-Namen-Text relativ zum Item — für
   * die häufigere Seitenstruktur mit einem eigenen Venue-Element statt
   * Gasteigs Tag-Link-System. Hat Vorrang vor venueTagHrefPattern, falls
   * beide gesetzt sind. */
  venueSelector?: string;
  /** Nur Items behalten, deren (kleingeschriebener) venueName mindestens
   * eine dieser Zeichenketten enthält — z.B. ["isarphilharmonie"], um von
   * einer Seite mit Tourneedaten nur Münchner Konzerte zu behalten. Leer/
   * fehlend = keine Filterung nach Venue. */
  venueAllowlist?: string[];
  /** Basis-URL zum Auflösen relativer href/src-Werte. */
  baseUrl?: string;
}

export function parseScrape(html: string, config: ScrapeConfig): ParseResult {
  const events: RawEvent[] = [];
  const errors: string[] = [];

  if (!config || typeof config !== "object" || !config.itemSelector) {
    errors.push(
      "scrape source is missing a valid config (itemSelector is required) — see ScrapeConfig in parsers/scrape.ts",
    );
    return { events, errors };
  }

  let document: Document;
  try {
    ({ document } = parseHTML(html));
  } catch (err) {
    errors.push(
      `failed to parse HTML: ${err instanceof Error ? err.message : String(err)}`,
    );
    return { events, errors };
  }

  const items = document.querySelectorAll(config.itemSelector);
  if (items.length === 0) {
    errors.push(
      `no elements matched itemSelector "${config.itemSelector}" — the site's markup may have changed`,
    );
    return { events, errors };
  }

  items.forEach((item, i) => {
    const label = `item ${i + 1}`;
    try {
      const title = extractText(
        item,
        config.titleSelector,
        config.titleAttribute,
        !config.titleFullText,
      );
      if (!title) {
        errors.push(`${label}: no title found via "${config.titleSelector}", skipped`);
        return;
      }

      const url = resolveUrl(
        extractText(item, config.urlSelector, config.urlAttribute ?? "href"),
        config.baseUrl,
      );

      const dateRaw = extractText(item, config.dateSelector, config.dateAttribute);
      const startDateTime = dateRaw ? parseFlexibleDate(dateRaw) : null;
      if (!startDateTime) {
        errors.push(`${label} ("${title}"): no parseable date via "${config.dateSelector}" (got "${dateRaw}"), skipped`);
        return;
      }

      const tagEls = config.tagsSelector ? Array.from(item.querySelectorAll(config.tagsSelector)) : [];
      // deno-lint-ignore no-explicit-any
      const tags = tagEls.map((t: any) => ({
        text: (t.textContent ?? "").trim(),
        href: t.getAttribute?.("href") ?? null,
      }));
      const tagTextsLower = tags.map((t) => t.text.toLowerCase());

      if (config.includeIfTagContains && config.includeIfTagContains.length > 0) {
        const wanted = config.includeIfTagContains.map((s) => s.toLowerCase());
        const matches = tagTextsLower.some((tag) => wanted.some((w) => tag.includes(w)));
        if (!matches) return; // not an error — most items on a general listing page are expected to be filtered out
      }

      // Sites that list multiple rooms/halls under one page (e.g. a venue
      // complex) can mark the room-specific tag via its link target rather
      // than its visible text — venueTagHrefPattern lets a config pick that
      // tag out instead of guessing from tag text alone. Falls back to
      // venueTagFallbackHrefPattern (e.g. the building-level location) if no
      // room-level tag matches. An event can carry SEVERAL room tags at once
      // (a festival spanning multiple halls) — if includeIfTagContains is
      // itself being used as a room filter, prefer whichever room-pattern
      // tag actually matches it over just the first one in DOM order, so a
      // multi-room event gets attributed to the room it was filtered for
      // rather than an arbitrary other room on the same event.
      const roomMatches = config.venueTagHrefPattern
        ? tags.filter((t) => t.href && new RegExp(config.venueTagHrefPattern!).test(t.href))
        : [];
      let venueName: string | null = null;
      if (roomMatches.length > 0) {
        const wanted = (config.includeIfTagContains ?? []).map((s) => s.toLowerCase());
        venueName = roomMatches.find((t) => wanted.includes(t.text.toLowerCase()))?.text
          ?? roomMatches[0].text;
      }
      if (!venueName && config.venueTagFallbackHrefPattern) {
        const re = new RegExp(config.venueTagFallbackHrefPattern);
        venueName = tags.find((t) => t.href && re.test(t.href))?.text ?? null;
      }
      if (config.venueSelector) {
        venueName = extractText(item, config.venueSelector) ?? venueName;
      }

      if (config.venueAllowlist && config.venueAllowlist.length > 0) {
        const wanted = config.venueAllowlist.map((s) => s.toLowerCase());
        const venueOk = venueName != null &&
          wanted.some((w) => venueName!.toLowerCase().includes(w));
        if (!venueOk) return; // not an error — a listing spanning many venues is expected to filter most items out
      }

      const description = config.descriptionSelector
        ? extractText(item, config.descriptionSelector)
        : null;
      const imageUrl = config.imageSelector
        ? resolveUrl(
          extractText(item, config.imageSelector, config.imageAttribute ?? "src"),
          config.baseUrl,
        )
        : null;

      events.push({
        externalId: url, // the detail-page URL is the natural stable id for a scraped item
        title,
        description,
        startDateTime,
        endDateTime: null,
        venueName,
        venueAddress: null,
        url,
        imageUrl,
        priceMin: null,
        priceMax: null,
        isFree: tagTextsLower.some((t) => t.includes("gratis") || t.includes("kostenlos")) || null,
      });
    } catch (err) {
      errors.push(
        `${label}: unexpected error — ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  });

  return { events, errors };
}

// deno-lint-ignore no-explicit-any
function extractText(root: any, selector: string, attribute?: string, firstTextNodeOnly = false): string | null {
  const el = root.querySelector(selector);
  if (!el) return null;
  if (attribute) {
    const val = el.getAttribute(attribute);
    return val ? val.trim() : null;
  }
  if (firstTextNodeOnly) {
    for (const child of el.childNodes) {
      if (child.nodeType === 3 /* TEXT_NODE */) {
        const text = (child.textContent ?? "").replace(/\s+/g, " ").trim();
        if (text) return text;
      }
    }
    return null;
  }
  const text = (el.textContent ?? "").replace(/\s+/g, " ").trim();
  return text || null;
}

function resolveUrl(value: string | null, baseUrl?: string): string | null {
  if (!value) return null;
  if (!baseUrl) return value;
  try {
    return new URL(value, baseUrl).toString();
  } catch {
    return value;
  }
}

/** Handles "YYYY-MM-DD" and "YYYY-MM-DD HH:MM" (the exact format observed
 * on gasteig.de's <time datetime> attribute — not standard ISO 8601, no
 * "T" separator, no timezone). Assumes Europe/Berlin local time, same DST
 * logic as parsers/rss.ts's toIsoWithBerlinOffset. */
function parseFlexibleDate(raw: string): string | null {
  const m = raw.trim().match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/);
  if (!m) return null;
  const year = parseInt(m[1], 10);
  const month = parseInt(m[2], 10);
  const day = parseInt(m[3], 10);
  const hour = m[4] !== undefined ? parseInt(m[4], 10) : 0;
  const minute = m[5] !== undefined ? parseInt(m[5], 10) : 0;

  const d = new Date(Date.UTC(year, month - 1, day));
  if (d.getUTCFullYear() !== year || d.getUTCMonth() !== month - 1 || d.getUTCDate() !== day) {
    return null;
  }

  const isSummer = isBerlinSummerTime(year, month, day, hour);
  const offset = isSummer ? "+02:00" : "+01:00";
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${year}-${pad(month)}-${pad(day)}T${pad(hour)}:${pad(minute)}:00${offset}`;
}

function isBerlinSummerTime(year: number, month: number, day: number, hour: number): boolean {
  const naiveMs = Date.UTC(year, month - 1, day, hour);
  const dstStart = lastSundayUtcMs(year, 2, 1);
  const dstEnd = lastSundayUtcMs(year, 9, 1);
  return naiveMs >= dstStart && naiveMs < dstEnd;
}

function lastSundayUtcMs(year: number, monthIndex0: number, hour: number): number {
  const lastDayOfMonth = new Date(Date.UTC(year, monthIndex0 + 1, 0)).getUTCDate();
  const lastDate = new Date(Date.UTC(year, monthIndex0, lastDayOfMonth));
  const dow = lastDate.getUTCDay();
  const lastSundayDate = lastDayOfMonth - dow;
  return Date.UTC(year, monthIndex0, lastSundayDate, hour);
}
