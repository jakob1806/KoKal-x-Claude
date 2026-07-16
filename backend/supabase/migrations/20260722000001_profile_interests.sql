-- Interessen fürs Profil (Genres/Komponisten/Venues), siehe docs/06-mvp-plan.md
-- §"MVP-Empfehlungslogik". Drei typisierte Verknüpfungstabellen statt einer
-- polymorphen — konsistent mit event_genres/event_participants im selben
-- Schema. "Komponisten" ist kein eigener Tabellentyp, sondern persons mit
-- 'komponist' in roles — profile_interest_persons deckt das direkt ab.
create table profile_interest_genres (
  user_id uuid references profiles(id) on delete cascade,
  genre_id uuid references genres(id) on delete cascade,
  primary key (user_id, genre_id)
);

create table profile_interest_persons (
  user_id uuid references profiles(id) on delete cascade,
  person_id uuid references persons(id) on delete cascade,
  primary key (user_id, person_id)
);

create table profile_interest_venues (
  user_id uuid references profiles(id) on delete cascade,
  venue_id uuid references venues(id) on delete cascade,
  primary key (user_id, venue_id)
);

alter table profile_interest_genres enable row level security;
alter table profile_interest_persons enable row level security;
alter table profile_interest_venues enable row level security;

create policy "Nutzer verwaltet eigene Genre-Interessen" on profile_interest_genres
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer verwaltet eigene Personen-Interessen" on profile_interest_persons
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer verwaltet eigene Venue-Interessen" on profile_interest_venues
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
