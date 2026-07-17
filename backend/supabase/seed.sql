-- Beispieldaten für die lokale Entwicklung (supabase db reset lädt diese Datei
-- automatisch, immer NACH allen Migrationen). Enthält nur noch FIKTIVE
-- Beispiel-Events zu Demonstrationszwecken, keine echten Ticketing-Daten.
-- Die realen Referenzdaten (Venues, Organizers, Personen, Ensembles, Werke)
-- leben seit Migration 20260803000001_real_reference_data.sql als echte
-- Migration, nicht mehr hier — siehe deren Kommentar für den Grund (Migrationen,
-- die per fester ID darauf verweisen, liefen sonst auf einer frischen Datenbank
-- vor dieser Datei und schlugen mit einer Foreign-Key-Verletzung fehl).

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
