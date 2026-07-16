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
import { parseIcal } from "./parsers/ical.ts";
import { parseRss } from "./parsers/rss.ts";
import { parseScrape } from "./parsers/scrape.ts";
import { parseSchemaOrg } from "./parsers/schema_org.ts";
import type { ParseResult } from "./types.ts";
import { upsertRawEvent } from "./write.ts";

const SUPPORTED_TYPES = new Set(["schema_org", "ical", "rss", "scrape"]);

// Identifiziert diese App als Absender statt einen echten Browser
// vorzutäuschen — Mindest-Transparenz für den scrape-Quellentyp (siehe
// parsers/scrape.ts für den vollen Kontext zu dieser Produktentscheidung).
const USER_AGENT = "KlassikMuenchenBot/1.0 (+event discovery app; contact via source venue)";

/** Bestes-Bemühen robots.txt-Check: nur "Disallow"-Präfixe unter
 * "User-agent: *", keine Wildcards/Regex-Muster, kein Crawl-Delay. Deckt den
 * Normalfall ab; bei Fetch-Fehler wird konservativ NICHT blockiert (fehlende
 * robots.txt heißt "alles erlaubt"), aber ein echter Fund einer verbotenen
 * Regel blockiert zuverlässig. */
async function isAllowedByRobots(targetUrl: string): Promise<boolean> {
  let robotsUrl: string;
  let path: string;
  try {
    const u = new URL(targetUrl);
    robotsUrl = `${u.origin}/robots.txt`;
    path = u.pathname || "/";
  } catch {
    return true;
  }

  let text: string;
  try {
    const res = await fetch(robotsUrl, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) return true;
    text = await res.text();
  } catch {
    return true;
  }

  let inWildcardGroup = false;
  const disallows: string[] = [];
  for (const rawLine of text.split("\n")) {
    const line = rawLine.split("#")[0].trim();
    if (!line) continue;
    const [field, ...rest] = line.split(":");
    const value = rest.join(":").trim();
    const key = field.trim().toLowerCase();
    if (key === "user-agent") {
      inWildcardGroup = value === "*";
    } else if (key === "disallow" && inWildcardGroup && value) {
      disallows.push(value);
    }
  }

  return !disallows.some((rule) => path.startsWith(rule));
}

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

  const { data: source, error: sourceError } = await supabase
    .from("sources")
    .select("id, name, type, url, venue_id, config")
    .eq("id", sourceId)
    .maybeSingle();

  if (sourceError) {
    return jsonResponse({ error: `failed to load source: ${sourceError.message}` }, 500);
  }
  if (!source) {
    return jsonResponse({ error: `source ${sourceId} not found` }, 404);
  }

  const { data: run, error: runError } = await supabase
    .from("ingestion_runs")
    .insert({ source_id: source.id, started_at: new Date().toISOString(), status: "running" })
    .select("id")
    .single();

  if (runError || !run) {
    return jsonResponse(
      { error: `failed to create ingestion_runs row: ${runError?.message ?? "unknown"}` },
      500,
    );
  }

  if (!SUPPORTED_TYPES.has(source.type)) {
    const message =
      `ingestion type '${source.type}' is not supported by the automatic worker (manual/api require separate handling)`;
    await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
    await touchSource(supabase, source.id, false);
    return jsonResponse({ status: "failed", error: message }, 422);
  }

  if (source.type === "scrape") {
    const allowed = await isAllowedByRobots(source.url);
    if (!allowed) {
      const message = `robots.txt disallows fetching ${source.url} — refusing to scrape`;
      await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
      await touchSource(supabase, source.id, false);
      return jsonResponse({ status: "failed", error: message }, 403);
    }
  }

  let responseBody: string;
  try {
    const res = await fetch(source.url, { headers: { "User-Agent": USER_AGENT } });
    if (!res.ok) {
      const message = `fetch failed: HTTP ${res.status} ${res.statusText}`;
      await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
      await touchSource(supabase, source.id, false);
      return jsonResponse({ status: "failed", error: message }, 502);
    }
    responseBody = await res.text();
  } catch (err) {
    const message = `fetch threw: ${err instanceof Error ? err.message : String(err)}`;
    await finishRun(supabase, run.id, "failed", { events_found: 0 }, [message]);
    await touchSource(supabase, source.id, false);
    return jsonResponse({ status: "failed", error: message }, 502);
  }

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
      case "scrape":
        parsed = parseScrape(responseBody, source.config);
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
    return jsonResponse({ status: "failed", error: message }, 500);
  }

  let created = 0;
  let updated = 0;
  let unchanged = 0;
  let flagged = 0;
  const writeErrors: string[] = [...parsed.errors];

  for (const raw of parsed.events) {
    const result = await upsertRawEvent(supabase, source, raw);
    switch (result.outcome) {
      case "created":
        created++;
        break;
      case "updated":
        updated++;
        break;
      case "unchanged":
        unchanged++;
        break;
      case "flagged":
        flagged++;
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

  return jsonResponse({
    status,
    events_found: attempted,
    events_created: created,
    events_updated: updated,
    events_unchanged: unchanged,
    events_flagged_for_review: flagged,
    error_count: writeErrors.length,
  });
});

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
  status: "success" | "partial" | "failed",
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
