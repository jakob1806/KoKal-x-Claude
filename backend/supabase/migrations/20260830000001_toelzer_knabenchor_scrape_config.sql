-- Der "Tölzer Knabenchor"-Source (Zeile existiert bereits, siehe
-- 20260817000002_import_excel_stammdaten.sql für das zugehörige Ensemble;
-- die sources-Zeile selbst wurde offenbar über das Admin-Dashboard-Formular
-- angelegt, ohne je eine config zu bekommen) hatte keinerlei
-- Scrape-Selektoren — jeder Lauf schlug mit "itemSelector is required" fehl.
--
-- robots.txt (toelzerknabenchor.de) geprüft am 2026-08-30: existiert nicht
-- (404), keine Einschränkungen.
--
-- Markup (per curl-Fetch verifiziert): SvelteKit-Seite, aber serverseitig
-- gerendert — die Termine stehen bereits im initialen HTML, kein
-- JS-Rendering nötig. Jeder Termin ist ein .event-card mit h3 (Titel),
-- zwei <p>-Geschwistern für Wochentag/"TT. Monat" (die zweite, mit Klasse
-- text-2xl, ist das Datum), einem unmarkierten <p> für die Uhrzeit als
-- erstes Kind eines .flex.gap-1.items-center.mb-1-Divs, und .italic für den
-- Venue-Text ("Stadt: Venue-Name" — der Chor tourt international, die
-- meisten Termine sind NICHT in München).
--
-- Datumsformat "TT. Monat" (voll ausgeschrieben bei nahen Terminen, z.B.
-- "09. Mai", abgekürzt bei weiter entfernten, z.B. "06. Jun") hat NIE ein
-- Jahr — parsers/scrape.ts::parseFlexibleDate() wurde um einen
-- entsprechenden Fallback erweitert (siehe Commit-Kontext), der das Jahr
-- wie beim bestehenden "TT.MM."-Kurzformat inferiert.
--
-- venueAllowlist auf "münchen": von 44 aktuell gelisteten Terminen liegen
-- nur 5 in München (Bayerische Staatsoper, Nationaltheater, Isarphilharmonie,
-- Herz-Jesu-Kirche) — der Rest sind Opernengagements des Chors in Zürich,
-- Berlin, Stuttgart, Dresden etc. Ohne Filter würden bei jedem Lauf ~39
-- "no venue match"-Fehlermeldungen protokolliert, obwohl das erwartetes
-- Verhalten ist (venues enthält bewusst nur Münchner Spielstätten, siehe
-- matching.ts resolveVenue()) — der Allowlist-Filter spart das unnötige
-- Rauschen, ohne die Sicherheitslogik selbst zu verdoppeln.
--
-- Live verifiziert (manueller Funktionsaufruf, 2026-08-30): 5 gefunden,
-- 4 erfolgreich angelegt/aktualisiert, 1 Fehlschlag (ein einzelner Termin
-- nennt im Venue-Feld eine komplette Adresse statt nur den Namen — die
-- Trigram-Ähnlichkeit zur venues-Zeile "Isarphilharmonie" fällt dadurch
-- unter den 0.5-Schwellwert; Einzelfall, keine strukturelle Lücke).
update sources
set config = jsonb_build_object(
  'itemSelector', '.event-card',
  'titleSelector', 'h3',
  'dateSelector', '.font-serif.text-2xl.text-center',
  'timeSelector', '.flex.gap-1.items-center.mb-1 > p:first-child',
  'venueSelector', '.italic',
  'venueAllowlist', jsonb_build_array('münchen')
)
where name = 'Tölzer Knabenchor';
