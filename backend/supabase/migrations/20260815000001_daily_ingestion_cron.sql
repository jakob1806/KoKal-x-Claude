-- Tägliche automatische Ingestion für alle aktiven Quellen.
--
-- Bisher wird backend/supabase/functions/ingest-source nur manuell über den
-- "Jetzt ausführen"-Button im Admin-Dashboard aufgerufen (siehe
-- admin/src/app/(dashboard)/sources/actions.ts, runSourceNow() — POST auf
-- ${SUPABASE_URL}/functions/v1/ingest-source mit {"source_id": "<uuid>"},
-- authentifiziert mit dem anon key als apikey- und Bearer-Header). Es gibt
-- noch KEINEN Scheduler: kein pg_cron in bisherigen Migrationen, keine
-- scheduled-function-Konfiguration in backend/supabase/config.toml, kein
-- GitHub-Action-Cron dafür. Diese Migration schließt genau diese Lücke,
-- indem sie täglich denselben HTTP-Aufruf für jede Quelle mit
-- status = 'active' auslöst — über pg_cron (Scheduling) + pg_net
-- (asynchrones HTTP aus der Datenbank heraus).
--
-- Fehlertoleranz pro Quelle: ingest-source ist bereits so gebaut, dass es
-- NIE wirft. index.ts umschließt jeden Schritt (fetch, Parser, Robots-Check,
-- Auth) einzeln und schreibt am Ende immer einen Status nach
-- ingestion_runs / sources.last_run_at + consecutive_failures, bevor es
-- antwortet (siehe touchSource()/finishRun() in index.ts). write.ts'
-- upsertRawEvent() kapselt zusätzlich seine gesamte Logik in ein
-- try/catch und liefert im Fehlerfall immer {outcome: "error", error}
-- zurück statt zu werfen. Eine kaputte Quelle kann also schon heute nicht
-- den restlichen Lauf crashen lassen. Als zusätzliche Absicherung auf
-- Datenbankseite (falls net.http_post selbst je einen Fehler wirft, z.B.
-- weil pg_net nicht aktiviert ist) wird unten trotzdem jeder einzelne
-- net.http_post-Aufruf in der FOR-Schleife mit einem eigenen
-- BEGIN/EXCEPTION-Block isoliert, damit ein Fehlschlag bei einer Quelle
-- nicht die Verarbeitung der übrigen Quellen abbricht.

-- ============================================================================
-- 1) Extensions aktivieren
-- ============================================================================
-- Auf Supabase müssen pg_cron/pg_net je nach Plan/Rolle stattdessen über
-- Dashboard -> Database -> Extensions aktiviert werden, falls die folgenden
-- CREATE EXTENSION-Statements mit einem Berechtigungsfehler fehlschlagen
-- (die Rolle, mit der der SQL Editor verbunden ist, hat nicht immer die
-- nötigen Rechte). In diesem Fall: dort beide Extensions einschalten und
-- den Rest dieser Datei danach erneut ausführen.
--
-- Anders als die meisten Supabase-Extensions (postgis, pgcrypto, ...), die
-- laut Konvention in das Schema "extensions" installiert werden (siehe
-- backend/supabase/config.toml, extra_search_path = ["public",
-- "extensions"]), bringen pg_cron und pg_net über ihre jeweilige
-- .control-Datei ein fest verdrahtetes, NICHT verschiebbares eigenes Schema
-- mit ("cron" bzw. "net", relocatable = false). Ein "with schema
-- extensions"-Zusatz würde hier also mit einem Fehler wie
-- 'extension "pg_cron" must be installed in schema "cron"' abgelehnt werden
-- — deshalb bewusst ohne Schema-Klausel, und unten entsprechend als
-- cron.schedule(...) / net.http_post(...) aufgerufen, nicht
-- extensions.cron.schedule(...).
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ============================================================================
-- 2) run_all_active_sources(): einmal ingest-source pro aktiver Quelle
-- ============================================================================
-- security invoker (Standard, wie auch in 20260717000001_venue_upsert_rpc.sql):
-- läuft als der Aufrufer. In der Praxis ist das hier immer die Rolle, die
-- diese Migration bzw. cron.schedule() unten ausführt (typischerweise
-- "postgres" über den SQL Editor) — als Superuser/Tabellenbesitzer bypasst
-- diese Rolle Row Level Security auf "sources" ohnehin, ganz unabhängig
-- davon, welche Rolle den pg_cron-Job letztlich ausführt.
create or replace function run_all_active_sources()
returns void
language plpgsql
as $$
declare
  -- Aus app/.env (SUPABASE_URL / SUPABASE_ANON_KEY) übernommen.
  v_supabase_url text := 'https://zqgzcspeqllrihfwmayn.supabase.co';
  -- anon key, kein Secret: dieselbe Konstante steckt bereits client-seitig
  -- im Flutter-App-Bundle und im Admin-Dashboard (NEXT_PUBLIC_SUPABASE_ANON_KEY,
  -- siehe admin/src/app/(dashboard)/sources/actions.ts runSourceNow()) und ist
  -- laut Supabase-Design bewusst öffentlich/für den Client bestimmt — Schutz
  -- kommt über RLS, nicht über Geheimhaltung dieses Keys. Der service_role
  -- key dagegen darf NIEMALS so eingebettet werden, er umgeht RLS komplett.
  v_anon_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxZ3pjc3BlcWxscmloZndtYXluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMjgwNjQsImV4cCI6MjA5OTcwNDA2NH0.3ClVL1kfQ3_ATqW0wSeggv3p-OlLlEnAt50_8R_voNg';
  r record;
begin
  for r in select id from sources where status = 'active' loop
    begin
      perform net.http_post(
        url := v_supabase_url || '/functions/v1/ingest-source',
        body := jsonb_build_object('source_id', r.id),
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'apikey', v_anon_key,
          'Authorization', 'Bearer ' || v_anon_key
        )
      );
    exception when others then
      -- net.http_post() queued die Anfrage nur asynchron über pg_net; die
      -- eigentliche HTTP-Antwort (Erfolg/Fehlschlag pro Quelle) verarbeitet
      -- ingest-source selbst, siehe Kommentar oben. Dieser exception-Block
      -- fängt nur den unwahrscheinlichen Fall ab, dass der Aufruf von
      -- net.http_post() selbst wirft (z.B. pg_net nicht aktiviert, kaputte
      -- Argumente) — geloggt statt die Schleife für die übrigen Quellen
      -- abzubrechen.
      raise warning 'run_all_active_sources: net.http_post fehlgeschlagen für source %: % (%)',
        r.id, sqlerrm, sqlstate;
    end;
  end loop;
end;
$$;

-- ============================================================================
-- 3) Täglich planen
-- ============================================================================
-- 04:00 Europe/Berlin ist für Münchner Nutzer:innen verkehrsarm. pg_cron
-- läuft auf Supabase in UTC und pg_cron selbst kennt keine automatische
-- DST-Umrechnung — der UTC-Versatz muss also von Hand gewählt (und zweimal
-- im Jahr nachgezogen) werden:
--   - Sommerzeit (CEST, UTC+2, ca. Ende März - Ende Oktober; heute,
--     2026-07-20, aktuell in Kraft): 04:00 Europe/Berlin = 02:00 UTC
--     -> '0 2 * * *'
--   - Winterzeit (CET, UTC+1): 04:00 Europe/Berlin = 03:00 UTC
--     -> '0 3 * * *'
-- Diese Migration setzt den Sommerzeit-Versatz ('0 2 * * *'). Sobald die
-- Uhren Ende Oktober auf CET zurückgestellt werden, feuert der Job ohne
-- weiteres Zutun um 03:00 statt 04:00 Uhr Berliner Zeit — bis jemand den
-- Job manuell auf '0 3 * * *' umstellt (erneut cron.schedule() mit
-- demselben Job-Namen 'daily-ingestion' aufrufen; das aktualisiert laut
-- pg_cron-Doku den bestehenden Job in-place statt einen Duplikat-Job
-- anzulegen, daher ist diese Migration auch beim erneuten Ausführen
-- gefahrlos).
select cron.schedule(
  'daily-ingestion',
  '0 2 * * *',
  $$ select run_all_active_sources(); $$
);
