-- Daten-Governance & Admin, siehe docs/02-database-schema.md §11
create table user_roles (
  user_id uuid references profiles(id) on delete cascade,
  role app_role not null,
  primary key (user_id, role)
);

create table event_change_log (
  id bigint generated always as identity primary key,
  event_id uuid references events(id) on delete cascade,
  changed_fields text[],
  old_values jsonb,
  new_values jsonb,
  changed_by text not null,
  changed_at timestamptz default now()
);
create index idx_event_change_log_event on event_change_log(event_id);

create table duplicate_candidates (
  id uuid primary key default gen_random_uuid(),
  event_a_id uuid references events(id),
  event_b_id uuid references events(id),
  similarity_score numeric(4,3),
  status text default 'pending',
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz default now()
);

create table error_reports (
  id bigint generated always as identity primary key,
  source text,
  message text not null,
  context jsonb default '{}',
  created_at timestamptz default now()
);
