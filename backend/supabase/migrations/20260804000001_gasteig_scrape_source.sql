-- Erste echte Scrape-Quelle: Gasteig HP8 / Isarphilharmonie
-- Veranstaltungsliste (gasteig.de/veranstaltungen). Auf ausdrücklichen
-- Nutzerwunsch angebunden, der die im MVP-Plan/Roadmap dokumentierte
-- "erst nach rechtlicher Einzelprüfung"-Verschiebung bewusst umgeht (siehe
-- backend/supabase/functions/ingest-source/parsers/scrape.ts für den vollen
-- Kontext). robots.txt für gasteig.de wurde vor dem Anlegen geprüft und
-- erlaubt /veranstaltungen/ (nur /wp-admin/, /wp-login.php, Such-Query-
-- Parameter sind gesperrt).
--
-- venue_id bleibt NULL: die Seite listet mehrere Säle/Standorte (Isar-
-- philharmonie, Halle E, Saal X, Kleiner Saal, Gasteig Motorama) unter
-- einer URL — die Zuordnung passiert pro Event über den venueTagHrefPattern-
-- Mechanismus im Scraper anhand des Raum-Tags, nicht über eine feste
-- Quellen-Venue.
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'Gasteig HP8 / Isarphilharmonie (Website-Scraping)',
  'scrape',
  'https://www.gasteig.de/veranstaltungen/',
  null,
  1440,
  'robots.txt (gasteig.de) geprüft am 2026-07-16, /veranstaltungen/ nicht gesperrt. '
    || 'ToS/Nutzungsbedingungen NICHT im Detail rechtlich geprüft — auf expliziten '
    || 'Nutzerwunsch angebunden, der die im MVP-Plan vorgesehene rechtliche '
    || 'Einzelprüfung bewusst überspringt.',
  'active',
  jsonb_build_object(
    'itemSelector', '[data-component="teaser"]',
    'titleSelector', 'h3',
    'urlSelector', 'a',
    'urlAttribute', 'href',
    'dateSelector', 'time',
    'dateAttribute', 'datetime',
    'imageSelector', 'img',
    'imageAttribute', 'src',
    'tagsSelector', '[data-component="tags"] li a',
    'includeIfTagContains', jsonb_build_array('musik', 'klassik'),
    'venueTagHrefPattern', '[?&]room=',
    'venueTagFallbackHrefPattern', '[?&]locations='
  )
);
