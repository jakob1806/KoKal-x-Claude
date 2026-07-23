-- Architektur-Dokument Abschnitt 0/4: Confidence-Schwellwert pro Quelle
-- statt eines global fixen Cutoffs (bisher LOW_CONFIDENCE_THRESHOLD=0.85
-- hart im Review-Queue-Client, admin/src/app/(dashboard)/review-queue/page.tsx).
-- "quick" = ab diesem Score gilt ein Event als unkritisch genug für einen
-- schnellen Blick statt einer Vollprüfung; "auto" bleibt informativ
-- (siehe 20260819000004_events_import_confidence.sql — review_status hat
-- weiterhin KEINEN Effekt auf Sichtbarkeit, status/RLS bleibt die einzige
-- Sichtbarkeits-Schranke). Default deckt sich mit dem bisherigen globalen
-- Wert, damit sich für bestehende Quellen ohne expliziten Eintrag nichts
-- ändert.
alter table sources add column confidence_thresholds jsonb not null
  default '{"auto": 0.95, "quick": 0.85}'::jsonb;

-- Architektur-Dokument Abschnitt 11: Hauptzugriffspfad Home-Feed/Kalender
-- filtert nach Region + Zeitraum + Sichtbarkeitsstatus gemeinsam.
-- region_id lebt auf venues (siehe 20260819000005_regions.sql), nicht auf
-- events selbst — der Feed-Query joint events.venue_id auf venues.region_id,
-- deshalb zwei Indizes statt des im Architektur-Dokument (Abschnitt 11)
-- vereinfacht genannten einzelnen events(region_id, ...)-Composite-Index.
create index venues_region_idx on venues (region_id);
create index events_venue_start_status_idx on events (venue_id, start_datetime, status);
