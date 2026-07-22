// Supabase Edge Function: manueller/geplanter Ingestion-Lauf für eine
// einzelne Quelle. Aufgerufen mit { source_id } — vom Admin-Dashboard
// "Jetzt ausführen"-Button, später auch von einem Scheduler (pg_cron o.ä.,
// noch nicht verdrahtet, siehe PR-Beschreibung).
//
// SUPABASE_URL und SUPABASE_SERVICE_ROLE_KEY werden von der Supabase-
// Runtime automatisch in jede Edge Function injiziert — kein manuell
// hinterlegtes Secret nötig. service_role, weil dieser Lauf nicht an eine
// eingeloggte Nutzersession gebunden ist und RLS bewusst umgehen muss, um
// events/ingestion_runs/duplicate_candidates zu schreiben.

// esm.sh (not npm:) — this is the pattern Supabase's own Edge Function
// docs/templates use, and the one most likely to be pre-cached/validated
// in the actual Supabase Edge Runtime rather than vanilla Deno.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseBayernCloud } from "./parsers/bayerncloud.ts";
import { isAllowedByRobots, USER_AGENT } from "../_shared/robots.ts";
import { parseIcal } from "./parsers/ical.ts";
import { parseRss } from "./parsers/rss.ts";
import { extractNextPageUrl, parseScrape } from "./parsers/scrape.ts";
import { parseSchemaOrg } from "./parsers/schema_org.ts";
import type { ParseResult } from "./types.ts";
import { upsertRawEvent } from "./write.ts";

const SUPPORTED_TYPES = new Set(["schema_org", "ical", "rss", "scrape", "api"]);

Deno.serve(async (req) => {
  let body: { source_id?: unknown };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid JSON body" }, 400);
  }

  const sourceId = typeof body.source_id === "string" ? body.source_id : null;
  if (!sourceId) {
    return jsonResponse({ error: "source_id is required" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { httpStatus, body: responseBody } = await runIngestion(supabase, sourceId);
  return jsonResponse(responseBody, httpStatus);
});

/** Führt einen kompletten Ingestion-Lauf für eine Quelle aus — der eigentliche
 * Kern, den bisher nur der Deno.serve-Handler oben direkt aufrufen konnte.
 * Als eigene, exportierte Funktion extrahiert, damit run-all-sources/index.ts
 * (der neue nebenläufige Orchestrator) sie in-process aufrufen kann, ohne
 * einen HTTP-Roundtrip auf sich selbst zu machen. */
export async function runIngestion(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  sourceId: string,
): Promise<{ httpStatus: number; body: Record<string, unknown> }> {
  function result(body: Record<string, unknown>, httpStatus = 200) {
    return { httpStatus, body };
  }

  const { data: source, error: sourceError } = await supabase
    .from("sources")
    .select("id, name, type, url, venue_id, organizer_id, person_id, ensemble_id, config, consecutive_failures")
    .eq("id", sourceId)
    .maybeSingle();
  // deno-lint-ignore no-explicit-any
  const config = (source?.config ?? {}) as Record<string, any>;

  if (sourceError) {
    return result({ error: `failed to load source: ${sourceError.message}` }, 500);
  }
  if (!source) {
    return result({ error: `source ${sourceId} not found` }, 404);
  }

  const { data: run, error: runError } = await supabase
    .from("ingestion_runs")
    .insert({ source_id: source.id, started_at: new Date().toISOString(), status: "running" })
    .select("id")
    .single();

  if (runError || !run) {
    return result(
      { error: `failed to create ingestion_runs row: ${runError?.message ?? "unknown"}` },
      500,
    );
  }

  if (!SUPPORTED_TYPES.has(source.type)) {
    const message =
      `ingestion type '${source.type}' is not supported by the automatic worker (manual/api require separate handling)`;
    await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
    await touchSource(supabase, source.id, false);
    return result({ status: "failed", error: message }, 422);
  }

  if (source.type === "scrape") {
    const allowed = await isAllowedByRobots(source.url);
    if (!allowed) {
      const message = `robots.txt disallows fetching ${source.url} — refusing to scrape`;
      await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
      await touchSource(supabase, source.id, false);
      return result({ status: "failed", error: message }, 403);
    }
  }

  // 'api'-Quellen (bisher nur BayernCloud Tourismus) sind Bearer-Token-
  // authentifiziert — anders als jede scrape/schema_org/rss/ical-Quelle,
  // die alle öffentlich/anonym abrufbar sind. Der Token selbst steht nie in
  // sources.config (das wäre ein Secret in der DB) — config trägt nur den
  // NAMEN des Supabase-Secrets, aus dem der Token zur Laufzeit gelesen wird.
  const headers: Record<string, string> = { "User-Agent": USER_AGENT };
  if (source.type === "api" && typeof config.authHeaderEnvVar === "string") {
    const token = Deno.env.get(config.authHeaderEnvVar);
    if (!token) {
      const message = `source.config.authHeaderEnvVar is "${config.authHeaderEnvVar}", but no such Supabase secret is set`;
      await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
      await touchSource(supabase, source.id, false);
      return result({ status: "failed", error: message }, 500);
    }
    headers["Authorization"] = `Bearer ${token}`;
  }

  // HTTP-Caching: viele Quellen unterstützen ETag/Last-Modified, manche
  // (v.a. einzelne Künstler-/Ensemble-Seiten) gar keine Cache-Header — dafür
  // zusätzlich ein Body-Hash-Fallback (siehe unten). httpCache lebt in
  // sources.config statt einer eigenen Spalte, konsistent mit dem
  // bestehenden config.authHeaderEnvVar-Muster.
  const httpCache = (config.httpCache ?? {}) as {
    etag?: string;
    lastModified?: string;
    lastBodyHash?: string;
  };
  if (httpCache.etag) headers["If-None-Match"] = httpCache.etag;
  if (httpCache.lastModified) headers["If-Modified-Since"] = httpCache.lastModified;

  let responseBody: string;
  let responseEtag: string | null = null;
  let responseLastModified: string | null = null;
  try {
    const res = await fetch(source.url, { headers });

    if (res.status === 304) {
      // Server bestätigt: seit dem letzten Lauf unverändert — Parsen/
      // Schreiben komplett überspringen. flagMissingEvents() wird bewusst
      // NICHT aufgerufen (kein seenEventIds für diesen Lauf vorhanden), das
      // würde sonst fälschlich alles als "verschwunden" markieren.
      await finishRun(supabase, run.id, "skipped_unchanged", { events_found: 0 }, []);
      await touchSource(supabase, source.id, true);
      return result({ status: "skipped_unchanged", events_found: 0 });
    }

    if (!res.ok) {
      const message = `fetch failed: HTTP ${res.status} ${res.statusText}`;
      await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
      await touchSource(supabase, source.id, false);
      return result({ status: "failed", error: message }, 502);
    }
    responseEtag = res.headers.get("etag");
    responseLastModified = res.headers.get("last-modified");
    responseBody = await res.text();
  } catch (err) {
    const message = `fetch threw: ${err instanceof Error ? err.message : String(err)}`;
    await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
    await touchSource(supabase, source.id, false);
    return result({ status: "failed", error: message }, 502);
  }

  // Fallback für Quellen ohne (verlässliche) ETag/Last-Modified-Header
  // (die meisten Künstler-/Ensemble-Seiten): Hash über den Response-Body,
  // Vergleich gegen den zuletzt gespeicherten Wert. Auch hier: bei
  // Übereinstimmung komplett überspringen statt nur den (in Phase 1 noch
  // gar nicht vorhandenen) teuren LLM-Schritt — aus denselben Gründen wie
  // beim 304-Fall oben.
  const bodyHash = await sha256Hex(responseBody);
  if (!responseEtag && !responseLastModified && httpCache.lastBodyHash === bodyHash) {
    await finishRun(supabase, run.id, "skipped_unchanged", { events_found: 0 }, []);
    await touchSource(supabase, source.id, true);
    return result({ status: "skipped_unchanged", events_found: 0 });
  }

  await supabase
    .from("sources")
    .update({
      config: {
        ...config,
        httpCache: {
          etag: responseEtag ?? undefined,
          lastModified: responseLastModified ?? undefined,
          lastBodyHash: bodyHash,
        },
      },
    })
    .eq("id", source.id);

  let parsed: ParseResult;
  try {
    switch (source.type) {
      case "schema_org":
        parsed = parseSchemaOrg(responseBody);
        break;
      case "ical":
        parsed = parseIcal(responseBody);
        break;
      case "rss":
        parsed = await parseRss(responseBody);
        break;
      case "scrape": {
        parsed = parseScrape(responseBody, source.config);
        // Paginierung: manche Quellen (residenz-muenchen.de) haben keine
        // vorhersagbare Seitennummer-URL-Systematik — der "nächste Seite"-
        // Link muss also pro Seite verfolgt werden statt eine Ziel-URL zu
        // berechnen. Bricht ab, sobald extractNextPageUrl() null liefert
        // (kein nextPageSelector konfiguriert ODER letzte Seite erreicht)
        // oder MAX_PAGES erreicht ist — kein unbegrenztes Nachladen.
        const MAX_PAGES = 5;
        let pageUrl = source.url;
        let pageHtml = responseBody;
        for (let page = 1; page < MAX_PAGES; page++) {
          const nextUrl = extractNextPageUrl(pageHtml, source.config, pageUrl);
          if (!nextUrl) break;
          // robots.txt einiger Quellen (z.B. erzbistum-muenchen.de) nennt
          // einen Crawl-Delay — der gilt pro Request, also auch zwischen den
          // Folgeseiten innerhalb dieses einen Laufs.
          const delayMs = source.config?.crawlDelayMs;
          if (typeof delayMs === "number" && delayMs > 0) {
            await new Promise((resolve) => setTimeout(resolve, delayMs));
          }
          let nextRes: Response;
          try {
            nextRes = await fetch(nextUrl, { headers: { "User-Agent": USER_AGENT } });
          } catch (err) {
            parsed.errors.push(
              `pagination: fetch of page ${page + 1} threw: ${err instanceof Error ? err.message : String(err)}`,
            );
            break;
          }
          if (!nextRes.ok) {
            parsed.errors.push(`pagination: fetch of page ${page + 1} failed: HTTP ${nextRes.status}`);
            break;
          }
          pageHtml = await nextRes.text();
          pageUrl = nextUrl;
          const nextParsed = parseScrape(pageHtml, source.config);
          parsed = { events: [...parsed.events, ...nextParsed.events], errors: [...parsed.errors, ...nextParsed.errors] };
        }
        break;
      }
      case "api":
        parsed = parseBayernCloud(responseBody);
        break;
      default:
        // Unreachable given the SUPPORTED_TYPES guard above, but keeps the
        // switch exhaustive without a non-null assertion.
        parsed = { events: [], errors: [`unhandled source type '${source.type}'`] };
    }
  } catch (err) {
    const message = `parser threw: ${err instanceof Error ? err.message : String(err)}`;
    await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
    await touchSource(supabase, source.id, false);
    return result({ status: "failed", error: message }, 500);
  }

  let created = 0;
  let updated = 0;
  let unchanged = 0;
  let flagged = 0;
  const writeErrors: string[] = [...parsed.errors];
  const seenEventIds: string[] = [];

  for (const raw of parsed.events) {
    const result = await upsertRawEvent(supabase, source, raw);
    switch (result.outcome) {
      case "created":
        created++;
        seenEventIds.push(result.eventId);
        break;
      case "updated":
        updated++;
        seenEventIds.push(result.eventId);
        break;
      case "unchanged":
        unchanged++;
        seenEventIds.push(result.eventId);
        break;
      case "flagged":
        flagged++;
        seenEventIds.push(result.eventId);
        break;
      case "error":
        writeErrors.push(`"${raw.title}": ${result.error}`);
        break;
    }
  }

  const attempted = parsed.events.length;
  const succeeded = created + updated + unchanged + flagged;
  const status = attempted === 0
    ? (parsed.errors.length > 0 ? "failed" : "success")
    : succeeded === 0
    ? "failed"
    : succeeded < attempted
    ? "partial"
    : "success";

  // Absage-Erkennung: nur für Quelltypen, die pro Lauf eine VOLLSTÄNDIGE
  // Liste aller aktuellen Termine liefern (ical/rss/schema_org). "scrape"
  // ist bewusst ausgeschlossen — MAX_PAGES=5 (oben) deckt nicht garantiert
  // jede Seite ab, ein zu früh abgebrochener Lauf würde sonst noch
  // existierende, nur nicht (erneut) gescrapte Events fälschlich als
  // "verschwunden" markieren. "api" ebenso ausgeschlossen (Paginierung/
  // Vollständigkeit nicht einheitlich garantiert über alle möglichen
  // API-Quellen hinweg). "manual" betrifft ohnehin nur Einzel-URL-Importe,
  // nie eine Liste. Zusätzlich: nur wenn dieser Lauf komplett fehlerfrei
  // war (keine Parse-Fehler, jedes RawEvent erfolgreich geschrieben) —
  // sonst könnte ein einzelner fehlgeschlagener Write ein weiterhin
  // existierendes Event fälschlich als "verschwunden" erscheinen lassen.
  const FULL_LISTING_TYPES = new Set(["ical", "rss", "schema_org"]);
  if (
    FULL_LISTING_TYPES.has(source.type) &&
    parsed.errors.length === 0 &&
    succeeded === attempted
  ) {
    await flagMissingEvents(supabase, source.id, seenEventIds);
  }

  await finishRun(
    supabase,
    run.id,
    status,
    {
      events_found: attempted,
      events_created: created,
      events_updated: updated,
      events_flagged_for_review: flagged,
    },
    writeErrors,
  );
  await touchSource(supabase, source.id, status !== "failed");

  return result({
    status,
    events_found: attempted,
    events_created: created,
    events_updated: updated,
    events_unchanged: unchanged,
    events_flagged_for_review: flagged,
    error_count: writeErrors.length,
  });
}

async function sha256Hex(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function finishRun(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  runId: string,
  status: "success" | "partial" | "failed" | "skipped_unchanged",
  counts: {
    events_found: number;
    events_created?: number;
    events_updated?: number;
    events_flagged_for_review?: number;
  },
  errors: string[],
) {
  const { error } = await supabase
    .from("ingestion_runs")
    .update({
      finished_at: new Date().toISOString(),
      status,
      events_found: counts.events_found,
      events_created: counts.events_created ?? 0,
      events_updated: counts.events_updated ?? 0,
      events_flagged_for_review: counts.events_flagged_for_review ?? 0,
      errors,
    })
    .eq("id", runId);

  if (error) {
    // Nothing more we can do — the run's own outcome already happened, this
    // would only affect the admin UI's visibility into it.
    console.error(`failed to finalize ingestion_runs ${runId}: ${error.message}`);
  }
}

/** Findet events dieser Quelle, die im aktuellen Lauf nicht (mehr)
 * vorkamen, und legt dafür einen cancellation_candidates-Eintrag zur
 * redaktionellen Prüfung an (20260815000003) — setzt NIE direkt
 * status='cancelled', das entscheidet die Redaktion im Admin-Dashboard.
 * Der partial unique index auf (event_id) where status='pending' sorgt
 * dafür, dass ein Event nicht bei jedem täglichen Lauf erneut geflaggt
 * wird, solange der vorherige Kandidat noch nicht reviewt wurde. */
async function flagMissingEvents(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  sourceId: string,
  seenEventIds: string[],
) {
  let query = supabase
    .from("events")
    .select("id")
    .eq("source_id", sourceId)
    .eq("status", "scheduled");

  // .not("id", "in", "()") ist ungültige Syntax bei einer leeren Liste —
  // wenn nichts gesehen wurde (z.B. leerer Feed), einfach alle scheduled
  // Events dieser Quelle als Kandidaten behandeln, ohne den in-Filter.
  if (seenEventIds.length > 0) {
    query = query.not("id", "in", `(${seenEventIds.join(",")})`);
  }

  const { data: missing, error } = await query;
  if (error) {
    console.error(`flagMissingEvents: lookup failed for source ${sourceId}: ${error.message}`);
    return;
  }
  if (!missing || missing.length === 0) return;

  // Supabase-js' .upsert({onConflict}) targets a plain unique constraint on
  // the given column(s) — it can't address our PARTIAL unique index
  // (event_id where status='pending'), so ON CONFLICT would either not
  // match it at all or (worse) collide with an old, already-reviewed
  // (non-pending) row for the same event and silently no-op there instead.
  // Check-then-insert avoids that ambiguity entirely; the partial index
  // still acts as a defensive DB-level backstop against a genuine race.
  const { data: existingPending, error: existingError } = await supabase
    .from("cancellation_candidates")
    .select("event_id")
    .eq("status", "pending")
    .in("event_id", missing.map((e: { id: string }) => e.id));
  if (existingError) {
    console.error(
      `flagMissingEvents: existing-candidate lookup failed for source ${sourceId}: ${existingError.message}`,
    );
    return;
  }

  const alreadyFlagged = new Set(
    (existingPending ?? []).map((r: { event_id: string }) => r.event_id),
  );
  const toInsert = missing
    .filter((e: { id: string }) => !alreadyFlagged.has(e.id))
    .map((e: { id: string }) => ({
      event_id: e.id,
      source_id: sourceId,
      reason: "missing_from_source",
      status: "pending",
    }));
  if (toInsert.length === 0) return;

  const { error: insertError } = await supabase.from("cancellation_candidates").insert(toInsert);
  if (insertError) {
    console.error(`flagMissingEvents: insert failed for source ${sourceId}: ${insertError.message}`);
  }
}

// deno-lint-ignore no-explicit-any
async function touchSource(supabase: any, sourceId: string, succeeded: boolean) {
  const nowIso = new Date().toISOString();

  if (succeeded) {
    await supabase
      .from("sources")
      .update({ last_run_at: nowIso, last_success_at: nowIso, consecutive_failures: 0 })
      .eq("id", sourceId);
    return;
  }

  const { data: current } = await supabase
    .from("sources")
    .select("consecutive_failures")
    .eq("id", sourceId)
    .maybeSingle();

  await supabase
    .from("sources")
    .update({
      last_run_at: nowIso,
      consecutive_failures: (current?.consecutive_failures ?? 0) + 1,
    })
    .eq("id", sourceId);
}
