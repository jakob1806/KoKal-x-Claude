-- Personen (Komponisten, Dirigenten, Solisten), siehe docs/02-database-schema.md §4
create table persons (
  id uuid primary key default uuid_generate_v4(),
  slug text not null unique,
  full_name text not null,
  roles participant_role[] not null default '{}',
  instrument text,
  biography_de text,
  biography_en text,
  birth_date date,
  death_date date,
  nationality text,
  photo_url text,
  gallery_urls text[] default '{}',
  website_url text,
  social_links jsonb default '{}',
  wikipedia_url text,
  is_verified boolean default false,
  search_vector tsvector generated always as (
    to_tsvector('german', coalesce(full_name,'') || ' ' || coalesce(biography_de,''))
  ) stored,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_persons_roles on persons using gin(roles);
create index idx_persons_search on persons using gin(search_vector);
create index idx_persons_name_trgm on persons using gin(full_name gin_trgm_ops);
