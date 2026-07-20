-- Absage-Kandidaten: ein Event, das in einem früheren Ingestion-Lauf einer
-- Quelle vorhanden war, aber im aktuellen Lauf plötzlich fehlt (z.B.
-- abgesagt, oder die Quelle listet es aus anderem Grund nicht mehr). Statt
-- automatisch auf status='cancelled' zu setzen (Risiko: unvollständige
-- Quell-Läufe erzeugen falsche Absagen), landet es hier zur redaktionellen
-- Prüfung — exakt dasselbe Muster wie duplicate_candidates
-- (20260715000012_governance_and_admin.sql), nur für "verschwunden statt
-- dupliziert".
create table cancellation_candidates (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade,
  source_id uuid references sources(id),
  reason text not null default 'missing_from_source',
  status text not null default 'pending',
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz default now()
);

-- Verhindert, dass derselbe Lauf (oder wiederholte tägliche Läufe, solange
-- niemand reviewt hat) für dasselbe Event mehrfach einen neuen Pending-
-- Kandidaten anlegt.
create unique index idx_cancellation_candidates_pending_event
  on cancellation_candidates(event_id)
  where status = 'pending';

alter table cancellation_candidates enable row level security;
create policy "Redaktion verwaltet Absage-Kandidaten" on cancellation_candidates
  for all using (is_admin_or_editor()) with check (is_admin_or_editor());
