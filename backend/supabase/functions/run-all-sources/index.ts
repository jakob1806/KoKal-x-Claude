// Orchestriert einen Ingestion-Lauf über ALLE aktiven Quellen mit echter,
// begrenzter Nebenläufigkeit — löst run_all_active_sources() (SQL-Funktion,
// siehe 20260815000001_daily_ingestion_cron.sql) ab, die pro Quelle einen
// unbegrenzten, nicht aggregierten pg_net.http_post-Fire-and-forget-Request
// abgesetzt hat (keine Backpressure, kein gesammeltes Ergebnis).
//
// Ruft ingest-source's Kernlogik (runIngestion()) DIREKT auf, nicht per HTTP
// gegen sich selbst — vermeidet einen unnötigen Netzwerk-Umweg auf derselben
// Edge-Runtime. Der tägliche pg_cron-Job ruft künftig nur noch DIESE eine
// Funktion auf statt pro Quelle einzeln zu loopen.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { runIngestion } from "../ingest-source/index.ts";

// Bewusst niedrig gehalten: viele Quellen könnten dieselbe Ziel-Domain
// treffen (z.B. mehrere Gasteig-Säle unter derselben Basis-URL), eine hohe
// Parallelität würde robots.txt-Crawl-Delay-Erwartungen einzelner Quellen
// unterlaufen, auch wenn jede Quelle für sich genommen ihren eigenen Delay
// einhält (siehe crawlDelayMs in ingest-source/index.ts) — das gilt nur
// zwischen Paginierungs-Schritten DERSELBEN Quelle, nicht quellenübergreifend.
const CONCURRENCY = 5;

interface RunSummary {
  sourceId: string;
  status: string;
  error?: string;
}

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data: sources, error } = await supabase
    .from("sources")
    .select("id")
    .eq("status", "active");

  if (error) {
    return jsonResponse({ error: `failed to load active sources: ${error.message}` }, 500);
  }

  const ids = (sources ?? []).map((s: { id: string }) => s.id);
  const results: RunSummary[] = [];

  let nextIndex = 0;
  async function worker() {
    while (nextIndex < ids.length) {
      const sourceId = ids[nextIndex++];
      try {
        const { body } = await runIngestion(supabase, sourceId);
        const status = typeof body.status === "string" ? body.status : "unknown";
        results.push({
          sourceId,
          status,
          error: typeof body.error === "string" ? body.error : undefined,
        });
      } catch (err) {
        results.push({
          sourceId,
          status: "failed",
          error: err instanceof Error ? err.message : String(err),
        });
      }
    }
  }

  const workerCount = Math.min(CONCURRENCY, ids.length);
  await Promise.all(Array.from({ length: workerCount }, () => worker()));

  const succeeded = results.filter((r) => r.status === "success" || r.status === "partial").length;
  const skipped = results.filter((r) => r.status === "skipped_unchanged").length;
  const failed = results.filter((r) => r.status === "failed").length;

  return jsonResponse({
    total: ids.length,
    succeeded,
    skipped,
    failed,
    errors: results
      .filter((r) => r.status === "failed")
      .slice(0, 20)
      .map((r) => `${r.sourceId}: ${r.error ?? "unknown"}`),
  });
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
