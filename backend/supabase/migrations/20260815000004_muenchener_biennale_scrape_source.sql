-- Scrape-Quelle: Münchener Biennale (Festival für neues Musiktheater),
-- Kalenderliste unter /en/programm/kalender. Echte Domain ist
-- muenchener-biennale.de (mit Bindestrich) — die in der Excel-Stammdaten-
-- Recherche notierte muenchenerbiennale.de existiert nicht.
--
-- robots.txt (muenchener-biennale.de) geprüft am 2026-08-15: "Allow: /"
-- ohne Einschränkungen.
--
-- Markup (per curl-Fetch am 2026-08-15 verifiziert, nicht nur aus einer
-- Beschreibung übernommen): jeder Termin ist ein
-- <div class="as df element fw" data-date="TT-M-JJJJ"> mit
-- .day-date .date (Text "23.04.", OHNE Jahr), .time-from (Text "18:00"),
-- .title-tags a (Detail-Link, enthält .title mit dem Titeltext) und
-- optional .location .hover-text (Venue-Name, nicht bei jedem Termin
-- vorhanden — die Termine ohne Location scheitern dann am Venue-Matching
-- und werden einzeln übersprungen statt den ganzen Lauf abzubrechen, siehe
-- write.ts/resolveVenue).
--
-- Das Datumsformat "TT.MM." ohne Jahr wurde in
-- parsers/scrape.ts::parseFlexibleDate() neu ergänzt (numericGerman-Zweig),
-- das Jahr wird wie beim bestehenden "Fr 24 Jul"-Fallback aus dem
-- aktuellen Datum abgeleitet.
--
-- ACHTUNG (Timing): das Festival findet nur zweijährlich statt (nächste
-- Ausgabe 08.–20.05.2026); die beim Recherche-Fetch gesehenen Termine
-- lagen zum Zeitpunkt dieser Migration (2026-08-15) bereits in der
-- Vergangenheit. Die Jahr-Inferenz nimmt dann automatisch das jeweils
-- nächste Jahr an — bei einer bereits abgelaufenen Ausgabe kann das
-- Termine fälschlich ins Folgejahr legen. Sollte harmlos sein (Duplicate-/
-- Fuzzy-Matching fängt grobe Fehlzuordnungen ab, und die Seite zeigt
-- vermutlich ohnehin erst wieder Termine, sobald das Programm der
-- nächsten Ausgabe feststeht), aber nach der ersten echten Läufen
-- stichprobenartig prüfen.
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'Münchener Biennale (Website-Scraping)',
  'scrape',
  'https://www.muenchener-biennale.de/en/programm/kalender',
  null,
  1440,
  'robots.txt (muenchener-biennale.de) geprüft am 2026-08-15, "Allow: /" ohne Einschränkungen. '
    || 'ToS/Nutzungsbedingungen NICHT im Detail rechtlich geprüft — analog zur bestehenden '
    || 'Gasteig-Quelle auf denselben expliziten Nutzerwunsch hin angebunden.',
  'active',
  jsonb_build_object(
    'itemSelector', '.list .element',
    'titleSelector', '.title-tags .title',
    'urlSelector', '.title-tags a',
    'dateSelector', '.day-date .date',
    'timeSelector', '.time-from',
    'venueSelector', '.location .hover-text',
    'baseUrl', 'https://www.muenchener-biennale.de/'
  )
);
