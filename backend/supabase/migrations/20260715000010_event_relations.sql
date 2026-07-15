-- Event-Relationen: Genres, Programm/Werke, Mitwirkende, siehe docs/02-database-schema.md §9

create table event_genres (
  event_id uuid references events(id) on delete cascade,
  genre_id uuid references genres(id),
  primary key (event_id, genre_id)
);

create table event_works (
  event_id uuid references events(id) on delete cascade,
  work_id uuid references works(id),
  position int not null default 0,
  after_intermission boolean default false,
  primary key (event_id, work_id, position)
);

create table event_participants (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid references events(id) on delete cascade,
  person_id uuid references persons(id),
  ensemble_id uuid references ensembles(id),
  role participant_role,
  display_order int default 0,
  check (person_id is not null or ensemble_id is not null)
);
create index idx_event_participants_event on event_participants(event_id);
create index idx_event_participants_person on event_participants(person_id);
create index idx_event_participants_ensemble on event_participants(ensemble_id);
