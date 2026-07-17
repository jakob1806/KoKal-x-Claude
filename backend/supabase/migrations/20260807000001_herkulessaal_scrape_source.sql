-- Dritte echte Scrape-Quelle: Herkulessaal-Konzerte über die
-- Veranstaltungssuche der Bayerischen Schlösserverwaltung
-- (residenz-muenchen.de). robots.txt existiert nicht (404) — keine
-- Einschränkungen angegeben.
--
-- Anders als Gasteig/MPhil: die URL selbst ist bereits über Query-Parameter
-- auf Konzert+Herkulessaal gefiltert (optArt=4&optOrt=18&optRaum=89), daher
-- reicht eine feste venue_id statt Tag-/Selektor-basierter Zuordnung —
-- jedes Event auf dieser Seite IST ein Herkulessaal-Konzert.
--
-- Bekannte Einschränkung: alte ASP-Seite ohne <time datetime>-Attribut
-- (reiner Text "Sonntag, 27. September 2026 / 19 Uhr", geparst über die
-- neue deutsche Datumserkennung in scrape.ts), und nicht jedes Event hat
-- eine eigene Detailseiten-URL (manche verlinken nur auf einen gemeinsamen
-- Ticketanbieter) — daher kein urlSelector, externalId bleibt null und
-- Wiedererkennung läuft über den Fuzzy-Match (Titel+Venue+Zeit) statt über
-- die exakte (source_id, external_id)-Kurzschluss-Prüfung. Nur Seite 1 von
-- 2 (10 von 17 Treffern) — die Seite paginiert ohne dass diese einfache
-- HTML-Quelle das nachbildet.
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'Herkulessaal Konzerte (Residenz München, Website-Scraping)',
  'scrape',
  'https://www.residenz-muenchen.de/deutsch/aktuell/veranst_erg.asp?PN=6&optArt=4&optOrt=18&optRaum=89&optMonat=999999&optSuchfeld=',
  '00000000-0000-0000-0000-000000000002',
  1440,
  'robots.txt (residenz-muenchen.de) geprüft am 2026-07-17: existiert nicht '
    || '(404), keine Einschränkungen angegeben. ToS/Nutzungsbedingungen '
    || 'NICHT im Detail rechtlich geprüft — auf expliziten Nutzerwunsch '
    || 'angebunden, der die im MVP-Plan vorgesehene rechtliche '
    || 'Einzelprüfung bewusst überspringt (siehe backend/supabase/'
    || 'functions/ingest-source/parsers/scrape.ts).',
  'active',
  jsonb_build_object(
    'itemSelector', '.tabelle',
    'titleSelector', 'strong',
    'dateSelector', '.spalte-20prozent',
    'descriptionSelector', '.spalte-70prozent span:not(.medium)'
  )
);
