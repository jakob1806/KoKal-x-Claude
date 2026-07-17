-- Sechste echte Scrape-Quelle: Prinzregententheater. Das Theater selbst hat
-- keinen eigenen Spielplan (Gastspielhaus ohne festen Bespieler) — die
-- offizielle Spielplan-Quelle ist stattdessen die Bayerische Theaterakademie
-- August Everding (theaterakademie.de/de/theater/programm), die dort neben
-- eigenen Akademie-Produktionen auch die Münchner Opernfestspiele und den
-- ARD-Musikwettbewerb listet (beide finden zu großen Teilen im
-- Prinzregententheater statt). robots.txt (theaterakademie.de) geprüft am
-- 2026-07-17: existiert nicht (404), keine Einschränkungen angegeben.
--
-- Site-Eigenheiten:
-- - Jedes Event erscheint dreifach im DOM (.datarecord--small/--middle/
--   --large, ein CSS-Responsive-Pattern mit paralleler statt rein
--   CSS-umbrochener Struktur) — itemSelector ist bewusst auf genau eine
--   Variante (--small) beschränkt, sonst 3x Duplikate.
-- - Datum steht als echtes <time datetime="YYYY-MM-DD">, kein Jahres-
--   Problem wie bei St. Michael. Uhrzeit steht in einem SEPARATEN
--   <time>-Element ohne datetime-Attribut (timeSelector). Manche Zeilen
--   zeigen zusätzlich eine "Werkeinführung"-Nebenzeit VOR der echten
--   Startzeit — die steht bewusst in einem <span>, nicht <time>, daher
--   greift "time:not([datetime])" zuverlässig nur die echte Startzeit ab.
-- - Die Seite listet mehrere Venues (Akademietheater, Akademiestudio,
--   Prinzregententheater) — venueAllowlist filtert auf Prinzregententheater.
--   venue_id trotzdem FEST gesetzt (nicht null wie bei MPhil): da der
--   Allowlist-Filter bereits ausschließlich Prinzregententheater-Zeilen
--   durchlässt, ist die feste ID hier zuverlässiger als ein Fuzzy-Match
--   gegen den vollen Venue-Text ("Prinzregententheater Großes Haus"), der
--   die Trigram-Ähnlichkeit unnötig verwässern würde.
--
-- BEKANNTE LÜCKE (live entdeckt, bewusst nicht behoben): Mehrrunden-Events
-- mit generischem, pro Runde IDENTISCHEM Titel (bisher beobachtet: "Inter-
-- national Musikwettbewerb der ARD") kollabieren zu einem einzigen Draft-
-- Event statt eines pro Runde. Ursache: find_matching_event() matcht nur
-- auf Titel-Trigram-Ähnlichkeit (+/-2h-Fenster) — bei identischem Titel
-- Ähnlichkeit 1.0, weit über der 0.7-Auto-Merge-Schwelle in write.ts, egal
-- wie sehr sich Datum/Beschreibung unterscheiden. Der eigentliche
-- Runden-Text ("Semifinale Fagott mit dem Münchener Kammerorchester") steht
-- auf der Seite als unverpackter Text-Node nach einem <br> innerhalb von
-- .flex-4, nicht in einem eigenen Element — mit dem aktuellen selektor-
-- basierten extractText() nicht sauber isolierbar, bräuchte eine neue
-- Extraktions-Primitive ("Text nach dem letzten <br>"). Betrifft nur diese
-- eine Wettbewerbs-Serie, nicht die übrigen ~134 Events dieser Quelle.
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'Prinzregententheater Spielplan via Theaterakademie (Website-Scraping)',
  'scrape',
  'https://theaterakademie.de/de/theater/programm',
  '00000000-0000-0000-0000-000000000003',
  1440,
  'robots.txt (theaterakademie.de) geprüft am 2026-07-17: existiert nicht '
    || '(404), keine Einschränkungen angegeben. ToS/Nutzungsbedingungen '
    || 'NICHT im Detail rechtlich geprüft — auf expliziten Nutzerwunsch '
    || 'angebunden, der die im MVP-Plan vorgesehene rechtliche '
    || 'Einzelprüfung bewusst überspringt (siehe backend/supabase/'
    || 'functions/ingest-source/parsers/scrape.ts).',
  'active',
  jsonb_build_object(
    'itemSelector', '.datarecord--small',
    'titleSelector', '.font-timesarial-sans.font-medium',
    'titleFullText', true,
    'urlSelector', '.flex-1 a',
    'urlAttribute', 'href',
    'dateSelector', 'time[datetime]',
    'dateAttribute', 'datetime',
    'timeSelector', 'time:not([datetime])',
    'descriptionSelector', '.eventSubtitle',
    'venueSelector', '.flex-3 span',
    'venueAllowlist', jsonb_build_array('prinzregententheater')
  )
);
