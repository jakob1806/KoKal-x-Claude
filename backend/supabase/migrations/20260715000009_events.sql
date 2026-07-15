-- Events (Kern-Tabelle), siehe docs/02-database-schema.md §9
create table events (
  id uuid primary key default uuid_generate_v4(),
  slug text not null unique,
  title text not null,
  subtitle text,
  category text,
  description_de text,
  program_notes_de text,

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
  remaining_tickets_status text,

  image_urls text[] default '{}',
  youtube_url text,
  website_url text,
  social_links jsonb default '{}',

  accessibility jsonb default '{}',
  is_open_air boolean default false,
  is_family_friendly boolean default false,

  status event_status not null default 'scheduled',

  source_id uuid references sources(id),
  external_id text,
  content_hash text,
  last_verified_at timestamptz,

  embedding vector(1536),

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
create unique index uq_events_source_external on events(source_id, external_id) where source_id is not null;

-- Umkreissuche, siehe docs/03-api-concept.md §2
create function events_nearby(lat float, lng float, radius_km float)
returns setof events as $$
  select e.* from events e
  join venues v on v.id = e.venue_id
  where ST_DWithin(v.location, ST_MakePoint(lng, lat)::geography, radius_km * 1000)
  order by ST_Distance(v.location, ST_MakePoint(lng, lat)::geography);
$$ language sql stable;
