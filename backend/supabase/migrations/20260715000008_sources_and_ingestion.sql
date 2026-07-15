-- Datenquellen & Ingestion-Läufe, siehe docs/02-database-schema.md §8
create table sources (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  type source_type not null,
  url text not null,
  venue_id uuid references venues(id),
  organizer_id uuid references organizers(id),
  crawl_frequency_minutes int not null default 1440,
  legal_basis text,
  status source_status not null default 'active',
  last_run_at timestamptz,
  last_success_at timestamptz,
  consecutive_failures int default 0,
  config jsonb default '{}',
  created_at timestamptz default now()
);

create table ingestion_runs (
  id uuid primary key default uuid_generate_v4(),
  source_id uuid references sources(id) not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running',
  events_found int default 0,
  events_created int default 0,
  events_updated int default 0,
  events_flagged_for_review int default 0,
  errors jsonb default '[]'
);
create index idx_ingestion_runs_source on ingestion_runs(source_id);
