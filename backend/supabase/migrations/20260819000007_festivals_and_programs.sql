-- Architektur-Dokument Abschnitt 2.2: Festivals als eigene Entität
-- (bisher nirgends abgebildet — ein "Münchner Opernfestspiele"-Event ist
-- aktuell nur ein Freitext-Präfix im Titel) und Konzertprogramme als
-- eigene, wiederverwendbare Struktur statt nur event_works (ein Programm
-- kann sich über mehrere Termine derselben Tournee wiederholen). Rein
-- additiv: events.festival_id/program_id sind nullable, kein bestehendes
-- Verhalten ändert sich.
create table festivals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description_de text,
  organizer_id uuid references organizers(id),
  region_id uuid references regions(id),
  recurring boolean not null default false,
  website_url text,
  created_at timestamptz not null default now()
);
alter table festivals enable row level security;
create policy "Festivals sind öffentlich lesbar" on festivals for select using (true);
create policy "Redaktion verwaltet Festivals" on festivals for all using (is_admin_or_editor()) with check (is_admin_or_editor());

alter table events add column festival_id uuid references festivals(id);

create table programs (
  id uuid primary key default gen_random_uuid(),
  title text,
  created_at timestamptz not null default now()
);
alter table programs enable row level security;
create policy "Programme sind öffentlich lesbar" on programs for select using (true);
create policy "Redaktion verwaltet Programme" on programs for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create table program_items (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references programs(id) on delete cascade,
  work_id uuid references works(id),
  position int not null,
  movement text,
  duration_minutes int
);
create index program_items_program_idx on program_items (program_id);
alter table program_items enable row level security;
create policy "Programmpunkte sind öffentlich lesbar" on program_items for select using (true);
create policy "Redaktion verwaltet Programmpunkte" on program_items for all using (is_admin_or_editor()) with check (is_admin_or_editor());

alter table events add column program_id uuid references programs(id);
