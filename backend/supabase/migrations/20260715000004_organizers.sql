-- Veranstalter, siehe docs/02-database-schema.md §7
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
