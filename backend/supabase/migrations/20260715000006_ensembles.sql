-- Ensembles (Chöre, Orchester, Kammerensembles), siehe docs/02-database-schema.md §4
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
