-- Erweitert sources um person_id/ensemble_id — bisher konnte eine Quelle nur
-- an eine Venue oder einen Organizer gebunden werden, nicht an eine einzelne
-- Person (Solist:in/Dirigent:in) oder ein Ensemble. Nötig, um "alle lokalen
-- Artists/Ensembles crawlen" (siehe docs zur Ingestion-Pipeline-Erweiterung)
-- als eigene Quellen abzubilden statt nur venue-/organizer-gebunden.
alter table sources add column person_id uuid references persons(id);
alter table sources add column ensemble_id uuid references ensembles(id);

-- Eine Quelle zielt auf höchstens EIN Entity — verhindert mehrdeutige
-- Zuordnung (z.B. gleichzeitig venue_id und person_id gesetzt). Deckt
-- rückwirkend auch venue_id/organizer_id ab, die bisher nie technisch
-- gegen Doppel-Belegung abgesichert waren (der Code hat es nie gebraucht,
-- aber jetzt, wo zwei weitere FKs dazukommen, lohnt sich eine einheitliche
-- Garantie).
alter table sources add constraint sources_single_entity_target check (
  (case when venue_id is not null then 1 else 0 end) +
  (case when organizer_id is not null then 1 else 0 end) +
  (case when person_id is not null then 1 else 0 end) +
  (case when ensemble_id is not null then 1 else 0 end) <= 1
);
