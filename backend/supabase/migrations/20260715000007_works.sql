-- Werke, siehe docs/02-database-schema.md §5
create table works (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  composer_id uuid references persons(id),
  catalog_number text,
  key_signature text,
  composition_year int,
  duration_minutes int,
  description_de text,
  created_at timestamptz default now()
);
create index idx_works_composer on works(composer_id);
create index idx_works_title_trgm on works using gin(title gin_trgm_ops);
