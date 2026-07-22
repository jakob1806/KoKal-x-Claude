-- Architektur-Dokument Abschnitt 2.2/4: Confidence Score pro Import.
-- review_status existiert bewusst als eigenes Feld NEBEN status
-- (draft/scheduled/...) — status steuert weiterhin Sichtbarkeit
-- (RLS-Policy "Veröffentlichte Events sind lesbar"), review_status ist rein
-- redaktionelle Metadaten für die künftige Review-Queue-Triage und hat
-- (noch) KEINEN Effekt auf Sichtbarkeit. Default 'published' für alle
-- bestehenden Events (die sind bereits redaktionell im Umlauf), neue
-- Ingestion-Importe setzen es nicht explizit -> bleibt vorerst ebenfalls
-- 'published', bis ein späterer Schritt das Score-Gating aktiviert.
alter table events add column import_confidence numeric;
alter table events add column review_status text not null default 'published'
  check (review_status in ('auto_published', 'needs_quick_check', 'needs_review', 'published', 'rejected'));
