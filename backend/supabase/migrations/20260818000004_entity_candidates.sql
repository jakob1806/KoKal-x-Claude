-- Kandidaten für neu entdeckte, bisher unbekannte Personen/Ensembles/
-- Institutionen — zur redaktionellen Freigabe, statt sie (wie bisher in
-- enrich-event-references, siehe Folgemigration/Code-Änderung) ungeprüft
-- direkt in persons/ensembles/organizers anzulegen. Mirrort exakt das
-- Muster von cancellation_candidates (20260815000003).
create type entity_candidate_type as enum ('person', 'ensemble', 'organizer');

create table entity_candidates (
  id uuid primary key default gen_random_uuid(),
  entity_type entity_candidate_type not null,
  name text not null,
  -- Freitext-Kontext (z.B. Fundstelle/URL/Ausschnitt) — je nach Quelle
  -- (Ingestion, Discovery) sehr unterschiedlich, daher jsonb statt fester Spalten.
  discovery_context jsonb default '{}',
  suggested_event_title text,
  suggested_event_start_datetime timestamptz,
  suggested_venue_id uuid references venues(id),
  source_url text,
  status text not null default 'pending',
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_person_id uuid references persons(id),
  created_ensemble_id uuid references ensembles(id),
  created_organizer_id uuid references organizers(id),
  created_at timestamptz default now()
);

-- Verhindert, dass wiederholte (tägliche) Ingestion-/Discovery-Läufe
-- denselben noch nicht geprüften Namen erneut als Kandidat anlegen.
create unique index idx_entity_candidates_pending_name
  on entity_candidates(entity_type, lower(name))
  where status = 'pending';

alter table entity_candidates enable row level security;
create policy "Redaktion verwaltet Entity-Kandidaten" on entity_candidates
  for all using (is_admin_or_editor()) with check (is_admin_or_editor());
