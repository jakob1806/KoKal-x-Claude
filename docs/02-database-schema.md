# Datenbankschema — PostgreSQL (Supabase)

## 1. Entity-Relationship-Übersicht

```
persons ──┬─< event_participants >──┬── events ──< event_works >── works ──> persons (composer)
          │                          │              │
          │                          │              └──> event_genres >── genres
ensembles ┘                          │
                                      ├──> venues
                                      ├──> organizers
                                      └──> sources (Herkunft der Daten)

users(profiles) ──< favorites >── events
users(profiles) ──< favorite_lists >──< favorite_list_items >── events
users(profiles) ──< user_favorite_persons / _ensembles / _venues >── persons/ensembles/venues
users(profiles) ──< notification_preferences
users(profiles) ──< push_tokens
users(profiles) ──< search_history
events ──< event_change_log
sources ──< ingestion_runs
events ──< duplicate_candidates >── events
```

Design-Prinzip: **Personen** (Individuen: Komponisten, Dirigenten, Solisten) und **Ensembles** (Gruppen: Chöre, Orchester, Kammer-Ensembles) sind bewusst getrennte Tabellen, da eine Person mehrere Rollen einnehmen kann (z. B. Dirigent *und* Komponist), ein Ensemble aber nie eine Einzelperson ist. `event_participants` verbindet beide flexibel mit einer Rolle pro Zeile.

---

## 2. Erweiterungen

```sql
create extension if not exists postgis;      -- Geodaten (Umkreissuche)
create extension if not exists pg_trgm;       -- Fuzzy-Matching für Dedupe & Suche
create extension if not exists vector;        -- Embeddings für Empfehlungen (Phase 3), Paketname "pgvector"
create extension if not exists pgmq;          -- Message Queue für Ingestion-Pipeline
```

UUIDs werden mit dem in Postgres eingebauten `gen_random_uuid()` erzeugt statt mit `uuid-ossp`/`uuid_generate_v4()` — kein Extension-Bedarf, und auf Supabase-Projekten liegt `uuid-ossp` ohnehin im `extensions`-Schema statt `public` und wäre unqualifiziert nicht auffindbar. `postgis`/`pg_trgm`/`vector`/`pgmq` werden hier bewusst ohne `WITH SCHEMA` erzeugt und landen dadurch in `public`, wo der Rest dieses Dokuments sie unqualifiziert referenziert (`geography`, `gin_trgm_ops`, `vector(...)`, `ST_*`).

---

## 3. Kern-Lookup-Tabellen

```sql
create type genre_type as enum (
  'oper', 'konzert', 'chormusik', 'kirchenmusik', 'kammermusik',
  'liederabend', 'orchester', 'orgel', 'jazz', 'neue_musik',
  'familienkonzert', 'kinder'
);

create table genres (
  id uuid primary key default gen_random_uuid(),
  slug genre_type not null unique,
  label_de text not null,
  label_en text,
  icon text,
  sort_order int default 0
);

create type participant_role as enum (
  'komponist', 'dirigent', 'solist', 'chorleiter', 'moderator'
);

create type ensemble_type as enum (
  'chor', 'orchester', 'kammerensemble', 'big_band', 'sonstiges'
);
```

---

## 4. Personen & Ensembles

```sql
create table persons (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  full_name text not null,
  roles participant_role[] not null default '{}',   -- z.B. {komponist,dirigent}
  instrument text,                                    -- bei Solisten, z.B. "Violine"
  biography_de text,
  biography_en text,
  birth_date date,
  death_date date,
  nationality text,
  photo_url text,
  gallery_urls text[] default '{}',
  website_url text,
  social_links jsonb default '{}',                    -- {instagram, facebook, ...}
  wikipedia_url text,
  is_verified boolean default false,                   -- redaktionell geprüft
  search_vector tsvector generated always as (
    to_tsvector('german', coalesce(full_name,'') || ' ' || coalesce(biography_de,''))
  ) stored,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_persons_roles on persons using gin(roles);
create index idx_persons_search on persons using gin(search_vector);
create index idx_persons_name_trgm on persons using gin(full_name gin_trgm_ops);

create table ensembles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  type ensemble_type not null,
  description_de text,
  description_en text,
  founded_year int,
  member_count int,
  photo_url text,
  gallery_urls text[] default '{}',
  website_url text,
  social_links jsonb default '{}',
  home_venue_id uuid references venues(id),
  is_verified boolean default false,
  search_vector tsvector generated always as (
    to_tsvector('german', coalesce(name,'') || ' ' || coalesce(description_de,''))
  ) stored,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_ensembles_search on ensembles using gin(search_vector);
create index idx_ensembles_name_trgm on ensembles using gin(name gin_trgm_ops);
```

---

## 5. Werke

```sql
create table works (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  composer_id uuid references persons(id),
  catalog_number text,              -- z.B. "BWV 244", "op. 125"
  key_signature text,                -- z.B. "d-Moll"
  composition_year int,
  duration_minutes int,
  description_de text,
  created_at timestamptz default now()
);
create index idx_works_composer on works(composer_id);
create index idx_works_title_trgm on works using gin(title gin_trgm_ops);
```

---

## 6. Venues (Veranstaltungsorte)

```sql
create table venues (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description_de text,
  address_street text not null,
  address_zip text not null,
  address_city text not null default 'München',
  location geography(Point, 4326) not null,   -- lat/lng via PostGIS
  photo_url text,
  gallery_urls text[] default '{}',
  website_url text,
  capacity int,
  accessibility jsonb default '{}',           -- {wheelchair, hearing_loop, sign_language, accessible_toilets}
  parking_info_de text,
  mvv_stops jsonb default '[]',                -- [{name, lines: ["U3","Tram 18"], walk_minutes}]
  is_verified boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_venues_location on venues using gist(location);
create index idx_venues_name_trgm on venues using gin(name gin_trgm_ops);
```

---

## 7. Veranstalter

```sql
create table organizers (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description_de text,
  logo_url text,
  website_url text,
  social_links jsonb default '{}',
  contact_email text,
  created_at timestamptz default now()
);
```

---

## 8. Datenquellen (Ingestion)

```sql
create type source_type as enum ('api', 'rss', 'ical', 'schema_org', 'scrape', 'manual');
create type source_status as enum ('active', 'paused', 'error', 'under_review');

create table sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type source_type not null,
  url text not null,
  venue_id uuid references venues(id),
  organizer_id uuid references organizers(id),
  crawl_frequency_minutes int not null default 1440,
  legal_basis text,                       -- Dokumentation der Rechtsgrundlage (robots.txt geprüft, API-ToS etc.)
  status source_status not null default 'active',
  last_run_at timestamptz,
  last_success_at timestamptz,
  consecutive_failures int default 0,
  config jsonb default '{}',              -- Connector-spezifische Config (Selektoren, Auth etc.)
  created_at timestamptz default now()
);

create table ingestion_runs (
  id uuid primary key default gen_random_uuid(),
  source_id uuid references sources(id) not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running', -- running|success|partial|failed
  events_found int default 0,
  events_created int default 0,
  events_updated int default 0,
  events_flagged_for_review int default 0,
  errors jsonb default '[]'
);
```

---

## 9. Events (Kern-Tabelle)

```sql
create type event_status as enum (
  'scheduled', 'sold_out', 'cancelled', 'postponed', 'draft'
);

create table events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  subtitle text,
  category text,                          -- primäre Anzeige-Kategorie
  description_de text,
  program_notes_de text,                  -- ausführliches Programm/Werkeinführung

  start_datetime timestamptz not null,
  end_datetime timestamptz,
  duration_minutes int,
  has_intermission boolean default false,

  venue_id uuid references venues(id) not null,
  organizer_id uuid references organizers(id),

  ticket_url text,
  price_min numeric(8,2),
  price_max numeric(8,2),
  price_currency text default 'EUR',
  is_free boolean default false,
  remaining_tickets_status text,          -- 'available' | 'few_left' | 'sold_out' | 'unknown'

  image_urls text[] default '{}',
  youtube_url text,
  website_url text,
  social_links jsonb default '{}',

  accessibility jsonb default '{}',       -- {wheelchair, hearing_loop, sign_language}
  is_open_air boolean default false,
  is_family_friendly boolean default false,

  status event_status not null default 'scheduled',

  source_id uuid references sources(id),
  external_id text,                        -- ID beim Datenanbieter, für Dedupe
  content_hash text,                       -- Hash relevanter Felder für Change-Detection
  last_verified_at timestamptz,

  embedding vector(1536),                  -- Phase 3: Empfehlungs-Embeddings

  search_vector tsvector generated always as (
    to_tsvector('german', coalesce(title,'') || ' ' || coalesce(subtitle,'') || ' ' || coalesce(description_de,''))
  ) stored,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_events_start on events(start_datetime);
create index idx_events_venue on events(venue_id);
create index idx_events_status on events(status);
create index idx_events_search on events using gin(search_vector);
create index idx_events_source_external on events(source_id, external_id);
create unique index uq_events_source_external on events(source_id, external_id) where source_id is not null;

-- Genres (n:m, ein Event kann mehreren Genres zugeordnet sein)
create table event_genres (
  event_id uuid references events(id) on delete cascade,
  genre_id uuid references genres(id),
  primary key (event_id, genre_id)
);

-- Werke im Programm, inkl. Reihenfolge
create table event_works (
  event_id uuid references events(id) on delete cascade,
  work_id uuid references works(id),
  position int not null default 0,
  after_intermission boolean default false,
  primary key (event_id, work_id, position)
);

-- Mitwirkende (Dirigent, Solisten, Chor, Orchester ...)
create table event_participants (
  id uuid primary key default gen_random_uuid(),
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
```

---

## 10. Nutzer, Profile & Personalisierung

```sql
-- Erweitert auth.users von Supabase Auth
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  home_location geography(Point, 4326),
  onboarding_completed boolean default false,
  created_at timestamptz default now()
);

create table favorites (
  user_id uuid references profiles(id) on delete cascade,
  event_id uuid references events(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, event_id)
);

create table favorite_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  name text not null,
  created_at timestamptz default now()
);

create table favorite_list_items (
  list_id uuid references favorite_lists(id) on delete cascade,
  event_id uuid references events(id) on delete cascade,
  added_at timestamptz default now(),
  primary key (list_id, event_id)
);

create table user_favorite_persons (
  user_id uuid references profiles(id) on delete cascade,
  person_id uuid references persons(id) on delete cascade,
  primary key (user_id, person_id)
);
create table user_favorite_ensembles (
  user_id uuid references profiles(id) on delete cascade,
  ensemble_id uuid references ensembles(id) on delete cascade,
  primary key (user_id, ensemble_id)
);
create table user_favorite_venues (
  user_id uuid references profiles(id) on delete cascade,
  venue_id uuid references venues(id) on delete cascade,
  primary key (user_id, venue_id)
);

create table notification_preferences (
  user_id uuid primary key references profiles(id) on delete cascade,
  new_matching_events boolean default true,
  price_changes boolean default true,
  almost_sold_out boolean default true,
  reminder_day_before boolean default true,
  followed_ensemble_new_event boolean default true
);

create table push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,   -- ios | android
  created_at timestamptz default now()
);

create table search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  query text not null,
  created_at timestamptz default now()
);

-- Signal für Empfehlungsalgorithmus
create table event_views (
  id bigint generated always as identity primary key,
  user_id uuid references profiles(id),
  event_id uuid references events(id),
  viewed_at timestamptz default now()
);
```

---

## 11. Daten-Governance & Admin

```sql
create type app_role as enum ('admin', 'editor');

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
  changed_by text not null,     -- 'system' | 'ingestion' | user_id als text
  changed_at timestamptz default now()
);

create table duplicate_candidates (
  id uuid primary key default gen_random_uuid(),
  event_a_id uuid references events(id),
  event_b_id uuid references events(id),
  similarity_score numeric(4,3),
  status text default 'pending',  -- pending | confirmed_duplicate | confirmed_distinct
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz default now()
);

create table error_reports (
  id bigint generated always as identity primary key,
  source text,          -- 'app' | 'ingestion' | 'admin'
  message text not null,
  context jsonb default '{}',
  created_at timestamptz default now()
);
```

---

## 12. Row Level Security (Beispiele)

```sql
alter table events enable row level security;
create policy "Öffentliche Events sind lesbar"
  on events for select
  using (status != 'draft');

alter table favorites enable row level security;
create policy "Nutzer sehen nur eigene Favoriten"
  on favorites for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

alter table user_roles enable row level security;
create policy "Nur Admins verwalten Rollen"
  on user_roles for all
  using (exists (select 1 from user_roles ur where ur.user_id = auth.uid() and ur.role = 'admin'));
```
Analoge Policies gelten für alle nutzerbezogenen Tabellen (`favorite_lists`, `notification_preferences`, `push_tokens`, `search_history`, `event_views`). Redaktionelle Schreibrechte auf `events`, `venues`, `persons`, `ensembles`, `works` sind auf `role in ('admin','editor')` beschränkt; Ingestion schreibt über einen Service-Role-Key (bypass RLS, nur serverseitig).

---

## 13. Materialisierte Views (Performance)

```sql
-- "Trending Searches" für die Suche
create materialized view trending_searches as
select query, count(*) as search_count
from search_history
where created_at > now() - interval '7 days'
group by query
order by search_count desc
limit 20;
-- Refresh via pg_cron alle 30 Minuten

-- "Heute in München" — vorberechnete Sicht für Home
create view events_today as
select * from events
where status = 'scheduled'
  and start_datetime::date = (now() at time zone 'Europe/Berlin')::date;
```
