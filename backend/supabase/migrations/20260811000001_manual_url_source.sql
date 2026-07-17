-- Geteilte "manual"-Quelle für das neue Admin-Feature "Event(s) per URL
-- hinzufügen" (extract-event-from-url Edge Function). Anders als die
-- config-getriebenen scrape/schema_org-Quellen ist das keine wiederkehrende,
-- feste URL — der Admin gibt bei jeder Nutzung eine andere URL ein. Alle so
-- angelegten Events teilen sich trotzdem diese eine sources-Zeile (statt
-- pro URL eine neue anzulegen), damit sie über die bestehende
-- events.source_id-Spalte einheitlich als "manuell hinzugefügt" erkennbar
-- bleiben und admin-seitig filterbar sind.
--
-- venue_id bleibt NULL: jede eingefügte URL kann eine andere Venue haben,
-- die Auflösung läuft pro Event über den bestehenden Fuzzy-Match
-- (find_matching_venue), nicht über eine feste Quellen-Venue.
--
-- crawl_frequency_minutes 0: wird nie automatisch angestoßen, nur ad hoc
-- über den "Event von URL"-Button im Admin-Dashboard.
--
-- Die Edge Function legt diese Zeile beim ersten Aufruf ohnehin idempotent
-- selbst an, falls sie fehlt (SELECT-vor-INSERT auf type+name, siehe
-- ensureManualSource in extract-event-from-url/index.ts) — das ist der
-- eigentliche Schutz gegen Duplikate. Kein ON CONFLICT hier: es gibt keinen
-- passenden Unique-Constraint, gegen den eine ID-lose INSERT sinnvoll
-- konfliktieren könnte, und Migrationen laufen ohnehin nur einmal pro
-- Datenbank.
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status
) values (
  'Manuelles Hinzufügen via URL',
  'manual',
  'manual:url-import',
  null,
  0,
  'Admin fügt einzelne URLs manuell hinzu, keine automatisierte, wiederkehrende Quelle — '
    || 'robots.txt wird trotzdem pro eingefügter URL geprüft (siehe extract-event-from-url/index.ts).',
  'active'
);
