-- Fünfte echte Scrape-Quelle: St. Michael (Jesuitenkirche), offizieller
-- Konzertkalender, bereits auf die Kategorie "Konzerte" gefiltert
-- (st-michael-muenchen.de/kalender-konzerte). robots.txt existiert nicht
-- (404), keine Einschränkungen angegeben, geprüft am 2026-07-17. Erste
-- Quelle außerhalb der bisherigen zwei Domains (gasteig.de/mphil.de,
-- residenz-muenchen.de) — deckt die im MVP-Plan explizit genannte "große
-- Kirchengemeinden"-Kategorie ab (docs/06-mvp-plan.md, Abschnitt
-- Ingestion-Pipeline).
--
-- Site-Eigenheit: Datum/Uhrzeit stehen in zwei getrennten Geschwister-
-- Elementen (.btn-caldate für Tag+Monat, .mr-2 .text-muted für die Uhrzeit)
-- statt in einem gemeinsamen Textblock — daher der neue timeSelector in
-- scrape.ts. Außerdem nennt die Seite nirgends (weder Liste noch Detail-
-- seite) das Jahr — "Fr 24 Jul" statt "24. Juli 2026". Die neue
-- Jahres-Inferenz in parseFlexibleDate() übernimmt das (siehe dortiger
-- Kommentar). Wie bei Herkulessaal kein urlSelector-Bedarf hier zwar
-- vorhanden (jedes Event hat eine eigene Detailseite), aber bewusst
-- trotzdem gesetzt für den exakten (source_id, external_id)-Abgleich statt
-- nur Fuzzy-Match.
--
-- venue_id fest gesetzt: die URL ist bereits auf St. Michael + Kategorie
-- Konzerte gescoped, keine per-Event-Venue-Erkennung nötig (wie
-- Herkulessaal/Allerheiligen-Hofkirche, nicht wie Gasteig/MPhil).
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'St. Michael Konzerte (Website-Scraping)',
  'scrape',
  'https://www.st-michael-muenchen.de/kalender-konzerte',
  '00000000-0000-0000-0000-000000000005',
  1440,
  'robots.txt (st-michael-muenchen.de) geprüft am 2026-07-17: existiert '
    || 'nicht (404), keine Einschränkungen angegeben. ToS/Nutzungsbedingungen '
    || 'NICHT im Detail rechtlich geprüft — auf expliziten Nutzerwunsch '
    || 'angebunden, der die im MVP-Plan vorgesehene rechtliche '
    || 'Einzelprüfung bewusst überspringt (siehe backend/supabase/'
    || 'functions/ingest-source/parsers/scrape.ts).',
  'active',
  jsonb_build_object(
    'itemSelector', '.callistitem',
    'titleSelector', '.caltitle a',
    'titleFullText', true,
    'urlSelector', '.caltitle a',
    'urlAttribute', 'href',
    'dateSelector', '.btn-caldate',
    'timeSelector', '.mr-2 .text-muted',
    'descriptionSelector', '.caldesc',
    'baseUrl', 'https://www.st-michael-muenchen.de/'
  )
);
