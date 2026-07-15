-- Enums & Lookup-Tabellen, siehe docs/02-database-schema.md §3

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

insert into genres (slug, label_de, sort_order) values
  ('oper', 'Oper', 1),
  ('konzert', 'Konzert', 2),
  ('chormusik', 'Chormusik', 3),
  ('kirchenmusik', 'Kirchenmusik', 4),
  ('kammermusik', 'Kammermusik', 5),
  ('liederabend', 'Liederabend', 6),
  ('orchester', 'Orchester', 7),
  ('orgel', 'Orgel', 8),
  ('jazz', 'Jazz', 9),
  ('neue_musik', 'Neue Musik', 10),
  ('familienkonzert', 'Familienkonzert', 11),
  ('kinder', 'Kinder', 12);

create type participant_role as enum (
  'komponist', 'dirigent', 'solist', 'chorleiter', 'moderator'
);

create type ensemble_type as enum (
  'chor', 'orchester', 'kammerensemble', 'big_band', 'sonstiges'
);

create type source_type as enum ('api', 'rss', 'ical', 'schema_org', 'scrape', 'manual');
create type source_status as enum ('active', 'paused', 'error', 'under_review');

create type event_status as enum (
  'scheduled', 'sold_out', 'cancelled', 'postponed', 'draft'
);

create type app_role as enum ('admin', 'editor');
