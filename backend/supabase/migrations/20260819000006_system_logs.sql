-- Architektur-Dokument Abschnitt 10 (Sicherheitskonzept): Audit-Log für
-- automatisierte/redaktionelle Änderungen an Stammdaten — bisher gibt es
-- mit event_change_log (20260812000001_event_attribution.sql, vermutlich)
-- nur ein Änderungsprotokoll für Events selbst, nicht für Entscheidungen
-- wie "Kandidat freigegeben", "Duplikate zusammengeführt" etc.
create table system_logs (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid,
  action text not null,
  -- 'system' für automatisierte Pipeline-Schritte, sonst die auth.uid()
  -- des handelnden Redakteurs — als text statt FK, damit ein Log-Eintrag
  -- auch nach Löschung eines profiles-Datensatzes lesbar bleibt.
  actor text not null,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now()
);
create index system_logs_entity_idx on system_logs (entity_type, entity_id);
create index system_logs_created_at_idx on system_logs (created_at desc);

-- Insert-Policy bewusst nur für Redaktion (is_admin_or_editor()), nicht
-- "true" — automatisierte Pipeline-Schritte (Edge Functions) laufen mit
-- dem service_role-Key und umgehen RLS ohnehin, ein offenes insert-für-alle
-- würde nur unauthentifizierten/anon-Clients erlauben, das Protokoll mit
-- beliebigen Einträgen zu fluten.
alter table system_logs enable row level security;
create policy "Redaktion liest Systemprotokoll" on system_logs for select using (is_admin_or_editor());
create policy "Redaktion schreibt ins Systemprotokoll" on system_logs for insert with check (is_admin_or_editor());
