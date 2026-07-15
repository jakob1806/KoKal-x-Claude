-- Venues, siehe docs/02-database-schema.md §6
create table venues (
  id uuid primary key default uuid_generate_v4(),
  slug text not null unique,
  name text not null,
  description_de text,
  address_street text not null,
  address_zip text not null,
  address_city text not null default 'München',
  location geography(Point, 4326) not null,
  photo_url text,
  gallery_urls text[] default '{}',
  website_url text,
  capacity int,
  accessibility jsonb default '{}',
  parking_info_de text,
  mvv_stops jsonb default '[]',
  is_verified boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_venues_location on venues using gist(location);
create index idx_venues_name_trgm on venues using gin(name gin_trgm_ops);
