-- Beispieldaten für die lokale Entwicklung (supabase db reset lädt diese Datei
-- automatisch). Venues/Personen sind reale, öffentlich bekannte Münchner
-- Institutionen bzw. historische Komponisten; die Events sind FIKTIVE
-- Beispieldatensätze zu Demonstrationszwecken, keine echten Ticketing-Daten.

-- Venues -----------------------------------------------------------------
insert into venues (id, slug, name, address_street, address_zip, address_city, location, capacity, is_verified) values
  ('00000000-0000-0000-0000-000000000001', 'isarphilharmonie', 'Isarphilharmonie', 'Hans-Preißinger-Straße 8', '81379', 'München', ST_MakePoint(11.5763, 48.1226)::geography, 1900, true),
  ('00000000-0000-0000-0000-000000000002', 'herkulessaal', 'Herkulessaal der Residenz', 'Hofgartenstraße 1', '80539', 'München', ST_MakePoint(11.5802, 48.1424)::geography, 1270, true),
  ('00000000-0000-0000-0000-000000000003', 'prinzregententheater', 'Prinzregententheater', 'Prinzregentenplatz 12', '81675', 'München', ST_MakePoint(11.6039, 48.1444)::geography, 1080, true),
  ('00000000-0000-0000-0000-000000000004', 'bayerische-staatsoper', 'Bayerische Staatsoper', 'Max-Joseph-Platz 2', '80539', 'München', ST_MakePoint(11.5765, 48.1397)::geography, 2100, true),
  ('00000000-0000-0000-0000-000000000005', 'st-michael', 'St. Michael', 'Neuhauser Straße 6', '80331', 'München', ST_MakePoint(11.5698, 48.1394)::geography, 800, true),
  ('00000000-0000-0000-0000-000000000006', 'allerheiligen-hofkirche', 'Allerheiligen-Hofkirche', 'Residenzstraße 1', '80333', 'München', ST_MakePoint(11.5786, 48.1414)::geography, 300, true);

-- Organizers ---------------------------------------------------------------
insert into organizers (id, slug, name) values
  ('00000000-0000-0000-0000-000000000101', 'muenchner-philharmoniker', 'Münchner Philharmoniker'),
  ('00000000-0000-0000-0000-000000000102', 'bachchor-muenchen', 'Bachchor München');

-- Personen (Komponisten) ----------------------------------------------------
insert into persons (id, slug, full_name, roles, birth_date, death_date, nationality, is_verified) values
  ('00000000-0000-0000-0000-000000000201', 'johann-sebastian-bach', 'Johann Sebastian Bach', '{komponist}', '1685-03-31', '1750-07-28', 'Deutsch', true),
  ('00000000-0000-0000-0000-000000000202', 'johannes-brahms', 'Johannes Brahms', '{komponist}', '1833-05-07', '1897-04-03', 'Deutsch', true),
  ('00000000-0000-0000-0000-000000000203', 'wolfgang-amadeus-mozart', 'Wolfgang Amadeus Mozart', '{komponist}', '1756-01-27', '1791-12-05', 'Österreichisch', true);

-- Ensembles ------------------------------------------------------------------
insert into ensembles (id, slug, name, type, home_venue_id, is_verified) values
  ('00000000-0000-0000-0000-000000000301', 'muenchner-philharmoniker', 'Münchner Philharmoniker', 'orchester', '00000000-0000-0000-0000-000000000001', true),
  ('00000000-0000-0000-0000-000000000302', 'bachchor-muenchen', 'Bachchor München', 'chor', '00000000-0000-0000-0000-000000000002', true);

-- Werke ------------------------------------------------------------------
insert into works (id, title, composer_id, catalog_number) values
  ('00000000-0000-0000-0000-000000000401', 'Matthäus-Passion', '00000000-0000-0000-0000-000000000201', 'BWV 244'),
  ('00000000-0000-0000-0000-000000000402', '4. Sinfonie e-Moll', '00000000-0000-0000-0000-000000000202', 'op. 98');

-- Events (fiktive Beispieldaten) --------------------------------------------
insert into events (id, slug, title, subtitle, description_de, start_datetime, duration_minutes, has_intermission, venue_id, organizer_id, price_min, price_max, status) values
  ('00000000-0000-0000-0000-000000000501', 'matthaeus-passion-beispiel', 'Matthäus-Passion BWV 244', 'Bachchor München', 'Beispiel-Veranstaltung für die lokale Entwicklung.', '2026-08-02 19:30:00+02', 190, true, '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000102', 25, 68, 'scheduled'),
  ('00000000-0000-0000-0000-000000000502', 'brahms-4-sinfonie-beispiel', 'Brahms — 4. Sinfonie', 'Münchner Philharmoniker', 'Beispiel-Veranstaltung für die lokale Entwicklung.', '2026-08-03 20:00:00+02', 75, false, '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000101', 20, 89, 'scheduled');

insert into event_genres (event_id, genre_id)
  select '00000000-0000-0000-0000-000000000501', id from genres where slug = 'kirchenmusik';
insert into event_genres (event_id, genre_id)
  select '00000000-0000-0000-0000-000000000502', id from genres where slug = 'orchester';

insert into event_works (event_id, work_id, position) values
  ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000401', 0),
  ('00000000-0000-0000-0000-000000000502', '00000000-0000-0000-0000-000000000402', 0);

insert into event_participants (event_id, ensemble_id, role, display_order) values
  ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000302', 'chorleiter', 0),
  ('00000000-0000-0000-0000-000000000502', '00000000-0000-0000-0000-000000000301', null, 0);
