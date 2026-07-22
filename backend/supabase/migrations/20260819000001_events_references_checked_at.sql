-- enrich-event-references wählte bisher Events allein danach aus, ob sie
-- schon eine event_works/event_participants-Zeile haben. Ein Event, dessen
-- Werke/Mitwirkende zwar erkannt, aber (noch) unbekannt sind (→ landen als
-- entity_candidates, keine Verknüpfung), bekommt dadurch NIE eine solche
-- Zeile und wurde bei jedem Lauf erneut ausgewählt — blockierte den
-- gesamten Batch-Fortschritt auf denselben paar Events, während die übrigen
-- nie an die Reihe kamen. references_checked_at trackt "wurde verarbeitet"
-- unabhängig vom Ergebnis.
alter table events add column references_checked_at timestamptz;
