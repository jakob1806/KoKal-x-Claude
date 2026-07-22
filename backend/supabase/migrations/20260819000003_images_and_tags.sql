-- Architektur-Dokument Abschnitt 2.2: Bild-Lizenz-Tracking und ein
-- kontrolliertes Tag-Vokabular statt Freitext (Genres existieren bereits als
-- eigene, reifere Tabelle — hier nicht angefasst/dupliziert). Rein additiv —
-- die App liest weiterhin events.image_urls[] (siehe home_providers.dart),
-- das Umstellen des Lesepfads auf images/primary_image_id ist ein
-- separater, bewusst nicht in dieser Migration enthaltener Schritt
-- (Breaking Change für die Flutter-App, braucht eigene Planung/Rollout).

create table images (
  id uuid primary key default gen_random_uuid(),
  storage_path text,                               -- null solange nur extern verlinkt (noch nicht heruntergeladen)
  source_url text not null,
  origin_type text not null check (origin_type in ('event','venue','ensemble','person','organizer')),
  origin_id uuid not null,
  photographer text,
  license_status text not null default 'unknown'
    check (license_status in ('unknown','confirmed_free','confirmed_licensed','rejected')),
  license_notes text,
  copyright_notice text,
  imported_at timestamptz not null default now(),
  -- Default true: ein Bild ist erst nach redaktioneller Prüfung "frei",
  -- nie automatisch — Copyright ist ein rechtliches, kein Datenqualitäts-Feld.
  needs_review boolean not null default true
);
create index images_origin_idx on images (origin_type, origin_id);

alter table events add column primary_image_id uuid references images(id);

alter table images enable row level security;
create policy "Bilder sind öffentlich lesbar, wenn freigegeben"
  on images for select
  using (license_status in ('confirmed_free', 'confirmed_licensed') or is_admin_or_editor());
create policy "Redaktion verwaltet Bilder"
  on images for all
  using (is_admin_or_editor())
  with check (is_admin_or_editor());

create table tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_ai_generated boolean not null default true      -- KI-Tags vs. redaktionelle Tags unterscheidbar
);
alter table tags enable row level security;
create policy "Tags sind öffentlich lesbar" on tags for select using (true);
create policy "Redaktion verwaltet Tags" on tags for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create table event_tags (
  event_id uuid not null references events(id) on delete cascade,
  tag_id uuid not null references tags(id) on delete cascade,
  primary key (event_id, tag_id)
);
alter table event_tags enable row level security;
create policy "Event-Tag-Zuordnung ist öffentlich lesbar" on event_tags for select using (true);
create policy "Redaktion verwaltet Event-Tag-Zuordnung" on event_tags for all using (is_admin_or_editor()) with check (is_admin_or_editor());
