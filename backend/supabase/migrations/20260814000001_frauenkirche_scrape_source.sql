-- Siebte Scrape-Quelle: Frauenkirche (Dom zu Unserer Lieben Frau) über den
-- bistumsweiten Konzertkalender des Erzbistums München und Freising
-- (erzbistum-muenchen.de/kunst-und-kultur/konzerte). robots.txt geprüft am
-- 2026-07-20: "Allow: /", "Crawl-delay: 30" — Crawling explizit erlaubt,
-- Delay wird über config.crawlDelayMs zwischen Paginierungs-Requests
-- eingehalten (siehe parsers/scrape.ts).
--
-- Site-Eigenheiten:
-- - Die Kalenderseite selbst lädt per JS/AJAX nachträglich (Spinner-
--   Platzhalter im initialen HTML) — der eigentliche Fetch geht direkt
--   gegen den zugrundeliegenden Endpoint (.../block/api/event-list/
--   ger-DE/800/37/1233983), der trotz "api" im Pfad ein HTML-Fragment
--   liefert (kein JSON) und ohne Bot-Schutz per einfachem GET erreichbar
--   ist (anders als staatsoper.de, das an Cloudflare scheitert — dort
--   bewusst keine Quelle angelegt).
-- - Der Kalender ist BISTUMSWEIT (München + ganz Oberbayern, u.a. auch
--   Landshut/Fürstenfeldbruck/Unterschleißheim) und musikalisch GEMISCHT
--   (Orgelkonzerte neben z.B. "Marktmusik", das kein eigenes Kategorie-
--   Tag hat) — auf Frauenkirche/München eingegrenzt über venueAllowlist
--   (location-Text endet auf ", München") und titleExcludeIfContains
--   für die beiden bisher beobachteten nicht-klassischen Titelmuster.
--   Absichtlich NUR auf Frauenkirche verengt statt bistumsweit: die
--   übrigen ~15-20 Kirchen im Feed sind noch keine eigenen venues-Zeilen,
--   und find_matching_venue() legt keine neuen Venues automatisch an
--   (siehe matching.ts) — bräuchte erst Geocoding je Kirche, bewusst
--   auf einen späteren Schritt verschoben.
-- - Datum/Zeit: .event-card__date-day trägt nur das Datum (datetime=
--   "YYYY-MM-DD"), die eigentliche Startzeit steckt in einem verschach-
--   telten .event-card__time time[datetime], teils als ISO-Intervall
--   ("2026-07-23T10:15/2026-07-23T10:45") statt Einzelwert — dateSelector
--   zeigt bewusst direkt auf Letzteres: parseFlexibleDate()s ISO-Regex
--   ist nicht endverankert, matcht also nur den Intervall-ANFANG und
--   ignoriert den "/end"-Teil, macht dieselbe Zeile für beide Fälle
--   nutzbar.
-- - Paginierung läuft über einen reinen JS-Button (`<button data-page="2">`,
--   kein href) statt eines Links — dafür neu: nextPageAttribute (liest
--   "data-page" statt href) und nextPageParam (setzt den gelesenen Wert
--   als "_page"-Query-Parameter auf die AKTUELLE URL statt ihn als
--   relative URL aufzulösen). _limit=50 statt der Default-10 der Seite,
--   um mit dem bestehenden MAX_PAGES=5-Deckel mehr Wochen abzudecken.
--
-- Venue mit fester ID statt fortlaufendem 00000000...-Pattern der
-- übrigen Seed-Venues: zuerst live gegen das verlinkte Dev-Projekt über
-- die create_venue()-RPC angelegt und mit dieser Quelle verifiziert,
-- bevor die Migration nachträglich geschrieben wurde — Migration
-- übernimmt bewusst dieselbe id, um keine zweite Frauenkirche-Zeile zu
-- erzeugen. Per `supabase migration repair` als bereits angewendet
-- markiert statt erneut ausgeführt.
insert into venues (
  id, slug, name, description_de, address_street, address_zip, address_city,
  location, website_url
) values (
  '2e8b7881-6f3f-40f7-a014-3f7665477148',
  'frauenkirche-muenchen',
  'Frauenkirche (Dom zu Unserer Lieben Frau)',
  'Die Bischofskirche des Erzbistums München und Freising und eines der '
    || 'bekanntesten Wahrzeichen Münchens, bekannt für ihre sommerlichen '
    || 'Orgelkonzerte.',
  'Frauenplatz 1',
  '80331',
  'München',
  ST_MakePoint(11.573889, 48.138611)::geography,
  'https://www.muenchner-dom.de'
);

insert into sources (
  id, name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'b39aa5a1-ba48-4dce-baa3-8094eb50f2b4',
  'Frauenkirche München Orgelkonzerte (Erzbistum München, Website-Scraping)',
  'scrape',
  'https://www.erzbistum-muenchen.de/block/api/event-list/ger-DE/800/37/1233983?_limit=50&_page=1',
  '2e8b7881-6f3f-40f7-a014-3f7665477148',
  1440,
  'robots.txt (erzbistum-muenchen.de) geprüft am 2026-07-20: "Allow: /", '
    || '"Crawl-delay: 30" — Crawling explizit erlaubt, Delay wird über '
    || 'config.crawlDelayMs zwischen Paginierungs-Requests eingehalten. '
    || 'ToS/Nutzungsbedingungen NICHT im Detail rechtlich geprüft — auf '
    || 'expliziten Nutzerwunsch angebunden, der die im MVP-Plan '
    || 'vorgesehene rechtliche Einzelprüfung bewusst überspringt (siehe '
    || 'backend/supabase/functions/ingest-source/parsers/scrape.ts). '
    || 'Quelle ist bistumsweit (München + Oberbayern), auf Frauenkirche/'
    || 'München per venueAllowlist eingegrenzt.',
  'active',
  jsonb_build_object(
    'itemSelector', 'article.event-card',
    'titleSelector', 'h3.event-card__title',
    'titleExcludeIfContains', jsonb_build_array('marktmusik', 'lange nacht der kirchen'),
    'urlSelector', 'a.event-card__link',
    'baseUrl', 'https://www.erzbistum-muenchen.de',
    'dateSelector', '.event-card__time time',
    'dateAttribute', 'datetime',
    'venueSelector', '.event-card__location-text',
    'venueAllowlist', jsonb_build_array('frauenkirche', 'unserer lieben frau'),
    'nextPageSelector', '.pagination__next',
    'nextPageAttribute', 'data-page',
    'nextPageParam', '_page',
    'crawlDelayMs', 30000
  )
);
