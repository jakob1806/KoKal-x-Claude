-- Architektur-Dokument Abschnitt 2.2/12: geografische Hierarchie als
-- Grundlage für Multi-City/Country, ohne dass sich am Verhalten für
-- München heute irgendetwas ändert. venues.region_id ist nullable und
-- rein additiv — bestehende Queries, die region_id nicht kennen, laufen
-- unverändert weiter.
--
-- is_active ist das Feature-Flag, mit dem künftig eine Stadt/ein Land für
-- die App freigeschaltet wird (siehe Roadmap Phase 3) — München startet
-- als einzige aktive Region.
create table regions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('country', 'state', 'city')),
  parent_id uuid references regions(id),
  name text not null,
  slug text not null unique,
  timezone text not null default 'Europe/Berlin',
  locale text not null default 'de-DE',
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  -- Eine city/state MUSS einen parent haben (kein Land ohne Kontext), ein
  -- country ist die Wurzel und hat keinen.
  constraint regions_parent_required check (
    (type = 'country' and parent_id is null) or (type <> 'country' and parent_id is not null)
  )
);
create index regions_parent_idx on regions (parent_id);

alter table regions enable row level security;
create policy "Regionen sind öffentlich lesbar" on regions for select using (true);
create policy "Redaktion verwaltet Regionen" on regions for all using (is_admin_or_editor()) with check (is_admin_or_editor());

alter table venues add column region_id uuid references regions(id);

-- Backfill: alle 37 bestehenden Venues sind München (address_city='München'
-- zum Zeitpunkt dieser Migration einheitlich, siehe Prüfung vor dem Schreiben
-- dieser Migration) -> direkt der neuen München-Region zuordnen.
do $$
declare
  v_country_id uuid;
  v_state_id uuid;
  v_city_id uuid;
begin
  insert into regions (type, name, slug, is_active) values ('country', 'Deutschland', 'de', true)
    returning id into v_country_id;
  insert into regions (type, parent_id, name, slug, is_active) values ('state', v_country_id, 'Bayern', 'bayern', true)
    returning id into v_state_id;
  insert into regions (type, parent_id, name, slug, is_active) values ('city', v_state_id, 'München', 'muenchen', true)
    returning id into v_city_id;

  update venues set region_id = v_city_id where region_id is null;
end $$;
