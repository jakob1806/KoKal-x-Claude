-- Achte echte Quelle, aber die erste GRUNDSÄTZLICH andere: BayernCloud
-- Tourismus (data.bayerncloud.digital), die offizielle, autorisierte
-- Tourismus-Datenplattform des Freistaats Bayern (Bayern Tourismus
-- Marketing GmbH). Anders als jede Scraping-Quelle in diesem Repo ist das
-- eine registrierte, autorisierte API-Anbindung mit vom Anbieter
-- ausgestelltem Token — keine "auf expliziten Nutzerwunsch, der die
-- rechtliche Einzelprüfung umgeht"-Situation wie bei den scrape-Quellen.
--
-- API-Vertrag (öffentliche Doku: bayerncloud.digital/daten-nutzen/api,
-- BayernCloud_API_Documentation_v3.yaml, geprüft 2026-07-17):
-- - Bearer-Token-Auth. Der Token selbst steht NIE hier oder sonst im Code —
--   config.authHeaderEnvVar nennt nur den Supabase-Secret-Namen, aus dem
--   der Ingestion-Worker ihn zur Laufzeit liest (siehe index.ts). Muss vom
--   Nutzer selbst gesetzt werden: `supabase secrets set
--   BAYERNCLOUD_API_TOKEN=<token> --project-ref zqgzcspeqllrihfwmayn`.
-- - GET .../api/v4/endpoints/list_events liefert Events für ganz Bayern,
--   keine dokumentierten Query-Parameter für Datum/Region/Kategorie-Filter.
--   "include=location,image,dc:additionalInformation" ist ein Best-Effort-
--   Versuch (nur für die POST-Variante mit Filter-Body offiziell belegt,
--   siehe unten) — schadet nicht, falls von der GET-Variante ignoriert.
-- - Venue-Filterung auf München läuft daher clientseitig im Parser
--   (parsers/bayerncloud.ts), nicht über einen API-Parameter — safer als
--   eine ungeprüft geratene Regions-Klassifikations-UUID zu verwenden.
--
-- WICHTIGE EINSCHRÄNKUNG, die für keine andere Quelle in diesem Repo gilt:
-- ich konnte diese Quelle NICHT live testen. Der Token ist ein echtes
-- Secret des Nutzers — das selbst einzutragen oder für einen Testlauf zu
-- verwenden fällt unter dieselbe Grenze wie beim Anthropic-API-Key (siehe
-- extract-event-from-url): Zugangsdaten trage ich nicht selbst ein, auch
-- nicht in die eigene Projekt-Infrastruktur. Der Parser ist daher bewusst
-- defensiv (siehe dessen Kommentar) und liefert bei einem Fehlschlag der
-- location-Erwartung eine klare Diagnose statt eines stillen "0 gefunden".
-- Sobald der Secret gesetzt ist, zeigt ein "Jetzt ausführen" im Admin-
-- Dashboard, ob die Annahmen stimmen.
--
-- Pflicht-Attribution laut Mail von BayernCloud Tourismus: "der
-- entsprechende Urheberrechtsvermerk der Datensätze muss mit angegeben
-- werden" (Nutzungsbedingungen Teil C §18 dataCycle) — copyrightNotice/
-- sdLicense werden pro Event erfasst (siehe Migration 20260812000001) und
-- müssen in der App angezeigt werden, sobald gesetzt (siehe EventDetail-
-- Änderung im selben PR).
insert into sources (
  name, type, url, venue_id, crawl_frequency_minutes, legal_basis, status, config
) values (
  'BayernCloud Tourismus Events (API)',
  'api',
  'https://data.bayerncloud.digital/api/v4/endpoints/list_events?include=location,image,dc:additionalInformation',
  null,
  1440,
  'Offizielle, autorisierte API-Anbindung mit vom Anbieter (Bayern Tourismus '
    || 'Marketing GmbH) ausgestelltem Zugangstoken — registriert und '
    || 'aktiviert am 2026-07-17. Nutzungsbedingungen: bayerncloud.digital, '
    || 'Teil C §18 dataCycle. Pflichtauflagen aus der Aktivierungs-Mail: '
    || '(1) regelmäßiger Abruf zur Sicherstellung von Korrektheit/'
    || 'Aktualität — erfüllt über crawl_frequency_minutes=1440 (täglich); '
    || '(2) Urheberrechtsvermerk der Datensätze muss mit angegeben werden — '
    || 'erfüllt über events.attribution_notice/attribution_license_url '
    || '(Migration 20260812000001) und deren Anzeige in der App.',
  'active',
  jsonb_build_object(
    'authHeaderEnvVar', 'BAYERNCLOUD_API_TOKEN'
  )
);
