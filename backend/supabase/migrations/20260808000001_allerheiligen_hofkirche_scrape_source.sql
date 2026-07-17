-- Vierte echte Scrape-Quelle: Allerheiligen-Hofkirche-Konzerte, dieselbe
-- Veranstaltungssuche wie die Herkulessaal-Quelle (residenz-muenchen.de,
-- Migration 20260807000001) — robots.txt-Prüfung von dort gilt unverändert
-- (gleiche Domain, geprüft am 2026-07-17: existiert nicht (404), keine
-- Einschränkungen angegeben).
--
-- Identischer Seitenaufbau wie Herkulessaal (dieselbe .tabelle/.spalte-
-- Struktur, live verifiziert), daher exakt dieselbe config wie dort — nur
-- optRaum in der URL (42 statt 89) und venue_id unterscheiden sich. Aus
-- demselben Grund kein urlSelector (siehe Kommentar in 20260807000001):
-- Wiedererkennung läuft über den Fuzzy-Match (Titel+Venue+Zeit).
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'Allerheiligen-Hofkirche Konzerte (Residenz München, Website-Scraping)',
  'scrape',
  'https://www.residenz-muenchen.de/deutsch/aktuell/veranst_erg.asp?PN=6&optArt=4&optOrt=18&optRaum=42&optMonat=999999&optSuchfeld=',
  '00000000-0000-0000-0000-000000000006',
  1440,
  'robots.txt (residenz-muenchen.de) geprüft am 2026-07-17 (siehe Migration '
    || '20260807000001_herkulessaal_scrape_source für den vollen Befund zur '
    || 'selben Domain): existiert nicht (404), keine Einschränkungen '
    || 'angegeben. ToS/Nutzungsbedingungen NICHT im Detail rechtlich geprüft '
    || '— auf expliziten Nutzerwunsch angebunden, der die im MVP-Plan '
    || 'vorgesehene rechtliche Einzelprüfung bewusst überspringt (siehe '
    || 'backend/supabase/functions/ingest-source/parsers/scrape.ts).',
  'active',
  jsonb_build_object(
    'itemSelector', '.tabelle',
    'titleSelector', 'strong',
    'dateSelector', '.spalte-20prozent',
    'descriptionSelector', '.spalte-70prozent span:not(.medium)'
  )
);
