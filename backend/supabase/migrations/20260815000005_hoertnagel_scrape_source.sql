-- Scrape-Quelle: Münchener Konzertdirektion Hörtnagel (privater Klassik-
-- Konzertveranstalter). Echte Domain ist muenchen.hoertnagel.de (nicht
-- www.hoertnagel.de, wie in der Excel-Stammdaten-Recherche notiert).
--
-- robots.txt (muenchen.hoertnagel.de) geprüft am 2026-08-15: /hn/
-- veranstaltungen ist NICHT gesperrt (nur /admin/, /comment/reply/,
-- /filter/tips, /node/add/, /search/, /user/* betroffen).
--
-- Markup (per curl-Fetch am 2026-08-15 verifiziert): jeder Termin ist ein
-- .event-overview-extended--item mit h3.headline1 a (Titel + Detail-Link),
-- <time datetime="..."> (siehe unten) und optional
-- .event-overview-extended--item-content--details--time-location h4
-- (Venue-Name, z.B. "Bibliotheksaal Polling" — liegt in Oberbayern, NICHT
-- München; da kein fester venue_id gesetzt ist, läuft die Zuordnung über
-- Fuzzy-Match gegen unsere ausschließlich Münchner venues-Tabelle, ein
-- Ort wie Polling matcht dort erwartungsgemäß nicht und wird einzeln
-- übersprungen statt fälschlich zugeordnet).
--
-- ACHTUNG (Parser-Fix nötig, siehe separater Commit/Migration-Kontext):
-- der <time datetime="..."> liefert hier eine ECHTE UTC-Instanz mit "Z"
-- (z.B. "2026-11-01T15:00:00Z" für 16:00 Ortszeit) statt naiver Lokalzeit
-- wie bei der bestehenden Gasteig-Quelle — parsers/scrape.ts::
-- parseFlexibleDate() wurde entsprechend erweitert, um ein Z/Offset-Suffix
-- zu erkennen und NICHT nochmal einen Berlin-Offset draufzurechnen.
--
-- Paginierung: "Mehr Veranstaltungen"-Link mit rel="next" (?page=1, ?page=2,
-- ...) — nextPageSelector deckt das ab, MAX_PAGES=5 in index.ts begrenzt
-- die Tiefe pro Lauf.
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'Münchener Konzertdirektion Hörtnagel (Website-Scraping)',
  'scrape',
  'https://muenchen.hoertnagel.de/hn/veranstaltungen',
  null,
  1440,
  'robots.txt (muenchen.hoertnagel.de) geprüft am 2026-08-15, /hn/veranstaltungen nicht gesperrt. '
    || 'ToS/Nutzungsbedingungen NICHT im Detail rechtlich geprüft — analog zur bestehenden '
    || 'Gasteig-Quelle auf denselben expliziten Nutzerwunsch hin angebunden.',
  'active',
  jsonb_build_object(
    'itemSelector', '.event-overview-extended--item',
    'titleSelector', 'h3.headline1 a',
    'urlSelector', 'h3.headline1 a',
    'dateSelector', 'time',
    'dateAttribute', 'datetime',
    'venueSelector', '.event-overview-extended--item-content--details--time-location h4',
    'baseUrl', 'https://muenchen.hoertnagel.de/',
    'nextPageSelector', 'a[rel="next"]'
  )
);
