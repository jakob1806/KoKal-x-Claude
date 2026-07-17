-- Zweite echte Scrape-Quelle: Münchner Philharmoniker Konzertkalender
-- (mphil.de/en/calendar). robots.txt existiert nicht (404) — nach
-- Standard-Konvention bedeutet das "keine Einschränkungen angegeben".
--
-- Anders als Gasteig: eigenes semantisches Venue-Element
-- (.m-mphil-concertlist__venue) statt Tag-Link-System, daher
-- venueSelector statt venueTagHrefPattern. Die Liste enthält auch
-- Tournee-Termine außerhalb Münchens (z.B. "Teatro Galli Rimini") —
-- venueAllowlist filtert auf "isarphilharmonie", das MPhil-Heimspielort
-- seit 2021. venue_id bleibt trotzdem NULL (nicht fix auf die Quelle
-- gesetzt): find_matching_venue() löst "Isarphilharmonie" zuverlässig
-- über den ohnehin vorhandenen Namensabgleich auf, und bleibt so
-- konsistent mit der Gasteig-Quelle, die denselben Saal von der anderen
-- Seite (als eigene Venue statt als MPhil-Heimspielstätte) erfassen kann,
-- ohne Konflikte über zwei fest verschiedene sources.venue_id-Werte.
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'Münchner Philharmoniker Konzertkalender (Website-Scraping)',
  'scrape',
  'https://www.mphil.de/en/calendar',
  null,
  1440,
  'robots.txt (mphil.de) geprüft am 2026-07-17: existiert nicht (404), '
    || 'keine Einschränkungen angegeben. ToS/Nutzungsbedingungen NICHT im '
    || 'Detail rechtlich geprüft — auf expliziten Nutzerwunsch angebunden, '
    || 'der die im MVP-Plan vorgesehene rechtliche Einzelprüfung bewusst '
    || 'überspringt (siehe backend/supabase/functions/ingest-source/'
    || 'parsers/scrape.ts).',
  'active',
  jsonb_build_object(
    'itemSelector', '.m-mphil-concertlist__card',
    'titleSelector', '.m-mphil-concertlist__headline',
    'titleFullText', true,
    'urlSelector', '.m-mphil-concertlist__detail-link',
    'urlAttribute', 'href',
    'dateSelector', '.m-mphil-concertlist__date',
    'dateAttribute', 'datetime',
    'descriptionSelector', '.m-mphil-concertlist__work-list',
    'venueSelector', '.m-mphil-concertlist__venue',
    'venueAllowlist', jsonb_build_array('isarphilharmonie'),
    'baseUrl', 'https://www.mphil.de/'
  )
);
