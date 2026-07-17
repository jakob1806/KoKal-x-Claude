-- Reale Referenzdaten (Venues, Organizers, Personen, Ensembles, Werke), bisher
-- ausschließlich in seed.sql. seed.sql wird von `supabase db reset` erst NACH
-- allen Migrationen angewendet — jede Migration, die per fester ID auf eine
-- dieser Zeilen verweist (z.B. eine sources-Quelle mit fixem venue_id), schlägt
-- daher auf einer frischen Datenbank (CI, oder jeder neue `db reset`) mit einer
-- Foreign-Key-Verletzung fehl, obwohl sie gegen die verlinkte Dev-Datenbank
-- (wo diese Zeilen bereits existieren) klaglos funktioniert. Konkret aufgefallen
-- bei PR #35 (Herkulessaal-Quelle, venue_id fest gesetzt).
--
-- Fix: die Zeilen, die laut seed.sql-Kopfkommentar ohnehin "reale, öffentlich
-- bekannte Münchner Institutionen bzw. historische Komponisten" sind (keine
-- Test-Fixtures), gehören als echte Referenzdaten in eine Migration, nicht in
-- die reine Lokal-Dev-Seed-Datei. seed.sql behält nur noch die explizit
-- fiktiven Beispiel-Events.
--
-- `on conflict (id) do nothing`: idempotent für die bereits befüllte
-- Remote-Datenbank (keine bestehenden Zeilen/Admin-Edits überschreiben) und
-- für jede frische Datenbank (Erstanlage).

insert into venues (id, slug, name, address_street, address_zip, address_city, location, capacity, is_verified) values
  ('00000000-0000-0000-0000-000000000001', 'isarphilharmonie', 'Isarphilharmonie', 'Hans-Preißinger-Straße 8', '81379', 'München', ST_MakePoint(11.5763, 48.1226)::geography, 1900, true),
  ('00000000-0000-0000-0000-000000000002', 'herkulessaal', 'Herkulessaal der Residenz', 'Hofgartenstraße 1', '80539', 'München', ST_MakePoint(11.5802, 48.1424)::geography, 1270, true),
  ('00000000-0000-0000-0000-000000000003', 'prinzregententheater', 'Prinzregententheater', 'Prinzregentenplatz 12', '81675', 'München', ST_MakePoint(11.6039, 48.1444)::geography, 1080, true),
  ('00000000-0000-0000-0000-000000000004', 'bayerische-staatsoper', 'Bayerische Staatsoper', 'Max-Joseph-Platz 2', '80539', 'München', ST_MakePoint(11.5765, 48.1397)::geography, 2100, true),
  ('00000000-0000-0000-0000-000000000005', 'st-michael', 'St. Michael', 'Neuhauser Straße 6', '80331', 'München', ST_MakePoint(11.5698, 48.1394)::geography, 800, true),
  ('00000000-0000-0000-0000-000000000006', 'allerheiligen-hofkirche', 'Allerheiligen-Hofkirche', 'Residenzstraße 1', '80333', 'München', ST_MakePoint(11.5786, 48.1414)::geography, 300, true)
on conflict (id) do nothing;

insert into organizers (id, slug, name) values
  ('00000000-0000-0000-0000-000000000101', 'muenchner-philharmoniker', 'Münchner Philharmoniker'),
  ('00000000-0000-0000-0000-000000000102', 'bachchor-muenchen', 'Bachchor München')
on conflict (id) do nothing;

insert into persons (id, slug, full_name, roles, birth_date, death_date, nationality, is_verified) values
  ('00000000-0000-0000-0000-000000000201', 'johann-sebastian-bach', 'Johann Sebastian Bach', '{komponist}', '1685-03-31', '1750-07-28', 'Deutsch', true),
  ('00000000-0000-0000-0000-000000000202', 'johannes-brahms', 'Johannes Brahms', '{komponist}', '1833-05-07', '1897-04-03', 'Deutsch', true),
  ('00000000-0000-0000-0000-000000000203', 'wolfgang-amadeus-mozart', 'Wolfgang Amadeus Mozart', '{komponist}', '1756-01-27', '1791-12-05', 'Österreichisch', true)
on conflict (id) do nothing;

insert into ensembles (id, slug, name, type, home_venue_id, is_verified) values
  ('00000000-0000-0000-0000-000000000301', 'muenchner-philharmoniker', 'Münchner Philharmoniker', 'orchester', '00000000-0000-0000-0000-000000000001', true),
  ('00000000-0000-0000-0000-000000000302', 'bachchor-muenchen', 'Bachchor München', 'chor', '00000000-0000-0000-0000-000000000002', true)
on conflict (id) do nothing;

insert into works (id, title, composer_id, catalog_number) values
  ('00000000-0000-0000-0000-000000000401', 'Matthäus-Passion', '00000000-0000-0000-0000-000000000201', 'BWV 244'),
  ('00000000-0000-0000-0000-000000000402', '4. Sinfonie e-Moll', '00000000-0000-0000-0000-000000000202', 'op. 98')
on conflict (id) do nothing;
