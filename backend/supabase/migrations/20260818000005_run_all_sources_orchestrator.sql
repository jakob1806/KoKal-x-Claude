-- Stellt run_all_active_sources() um: statt pro aktiver Quelle einen
-- eigenen, unbegrenzten pg_net.http_post-Fire-and-forget-Request
-- abzusetzen (keine Backpressure, kein gesammeltes Ergebnis), ruft die
-- Funktion jetzt nur noch EINMAL die neue Edge Function run-all-sources
-- auf, die den Fan-out mit echter, begrenzter Nebenläufigkeit selbst
-- übernimmt (siehe backend/supabase/functions/run-all-sources/index.ts).
-- Der pg_cron-Job 'daily-ingestion' selbst bleibt unverändert (ruft
-- weiterhin nur run_all_active_sources()), nur dessen Implementierung
-- ändert sich hier.
create or replace function run_all_active_sources()
returns void
language plpgsql
as $$
declare
  v_supabase_url text := 'https://zqgzcspeqllrihfwmayn.supabase.co';
  v_anon_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxZ3pjc3BlcWxscmloZndtYXluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMjgwNjQsImV4cCI6MjA5OTcwNDA2NH0.3ClVL1kfQ3_ATqW0wSeggv3p-OlLlEnAt50_8R_voNg';
begin
  perform net.http_post(
    url := v_supabase_url || '/functions/v1/run-all-sources',
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_anon_key,
      'Authorization', 'Bearer ' || v_anon_key
    )
  );
end;
$$;
