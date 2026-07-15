-- Row Level Security, siehe docs/02-database-schema.md §12
-- Helper als SECURITY DEFINER, damit Policies nicht auf die durch RLS
-- geschützte user_roles-Tabelle selbstreferenzierend zugreifen müssen
-- (klassische Bootstrapping-Falle bei rollenbasierten RLS-Policies).
create function is_admin_or_editor()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from user_roles
    where user_id = auth.uid() and role in ('admin', 'editor')
  );
$$;

create function is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from user_roles where user_id = auth.uid() and role = 'admin');
$$;

-- Öffentlich lesbare Referenzdaten: alle dürfen lesen, nur Redaktion schreibt
alter table venues enable row level security;
alter table organizers enable row level security;
alter table persons enable row level security;
alter table ensembles enable row level security;
alter table works enable row level security;
alter table genres enable row level security;

create policy "Öffentlich lesbar" on venues for select using (true);
create policy "Redaktion verwaltet Venues" on venues for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create policy "Öffentlich lesbar" on organizers for select using (true);
create policy "Redaktion verwaltet Organizers" on organizers for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create policy "Öffentlich lesbar" on persons for select using (true);
create policy "Redaktion verwaltet Personen" on persons for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create policy "Öffentlich lesbar" on ensembles for select using (true);
create policy "Redaktion verwaltet Ensembles" on ensembles for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create policy "Öffentlich lesbar" on works for select using (true);
create policy "Redaktion verwaltet Werke" on works for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create policy "Öffentlich lesbar" on genres for select using (true);
create policy "Redaktion verwaltet Genres" on genres for all using (is_admin_or_editor()) with check (is_admin_or_editor());

-- Events: veröffentlichte Events öffentlich lesbar, Entwürfe nur für Redaktion
alter table events enable row level security;
alter table event_genres enable row level security;
alter table event_works enable row level security;
alter table event_participants enable row level security;

create policy "Veröffentlichte Events sind lesbar" on events for select using (status != 'draft' or is_admin_or_editor());
create policy "Redaktion verwaltet Events" on events for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create policy "Öffentlich lesbar" on event_genres for select using (true);
create policy "Redaktion verwaltet event_genres" on event_genres for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create policy "Öffentlich lesbar" on event_works for select using (true);
create policy "Redaktion verwaltet event_works" on event_works for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create policy "Öffentlich lesbar" on event_participants for select using (true);
create policy "Redaktion verwaltet event_participants" on event_participants for all using (is_admin_or_editor()) with check (is_admin_or_editor());

-- Nutzerbezogene Tabellen: nur eigene Zeilen
alter table profiles enable row level security;
alter table favorites enable row level security;
alter table favorite_lists enable row level security;
alter table favorite_list_items enable row level security;
alter table user_favorite_persons enable row level security;
alter table user_favorite_ensembles enable row level security;
alter table user_favorite_venues enable row level security;
alter table notification_preferences enable row level security;
alter table push_tokens enable row level security;
alter table search_history enable row level security;
alter table event_views enable row level security;

create policy "Nutzer sieht eigenes Profil" on profiles for select using (auth.uid() = id or is_admin_or_editor());
create policy "Nutzer verwaltet eigenes Profil" on profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Nutzer legt eigenes Profil an" on profiles for insert with check (auth.uid() = id);

create policy "Nutzer verwaltet eigene Favoriten" on favorites for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer verwaltet eigene Listen" on favorite_lists for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer verwaltet eigene Listeneinträge" on favorite_list_items for all
  using (exists (select 1 from favorite_lists l where l.id = list_id and l.user_id = auth.uid()))
  with check (exists (select 1 from favorite_lists l where l.id = list_id and l.user_id = auth.uid()));

create policy "Nutzer verwaltet eigene Interessen (Personen)" on user_favorite_persons for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer verwaltet eigene Interessen (Ensembles)" on user_favorite_ensembles for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer verwaltet eigene Interessen (Venues)" on user_favorite_venues for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Nutzer verwaltet eigene Benachrichtigungseinstellungen" on notification_preferences for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer verwaltet eigene Push-Tokens" on push_tokens for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer sieht eigene Suchhistorie" on search_history for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Nutzer sieht eigene Event-Views" on event_views for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Governance & Admin: ausschließlich Redaktion/Admin
alter table user_roles enable row level security;
alter table event_change_log enable row level security;
alter table duplicate_candidates enable row level security;
alter table error_reports enable row level security;
alter table sources enable row level security;
alter table ingestion_runs enable row level security;

create policy "Nur Admins verwalten Rollen" on user_roles for all using (is_admin()) with check (is_admin());
create policy "Redaktion sieht Change-Log" on event_change_log for select using (is_admin_or_editor());
create policy "Redaktion verwaltet Duplikate" on duplicate_candidates for all using (is_admin_or_editor()) with check (is_admin_or_editor());
create policy "Redaktion sieht Fehlerberichte" on error_reports for select using (is_admin_or_editor());
create policy "Redaktion verwaltet Quellen" on sources for all using (is_admin_or_editor()) with check (is_admin_or_editor());
create policy "Redaktion sieht Ingestion-Läufe" on ingestion_runs for select using (is_admin_or_editor());
