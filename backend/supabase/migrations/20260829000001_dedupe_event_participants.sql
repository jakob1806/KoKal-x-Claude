-- Behebt einen echten Datenfehler: enrich-event-references/index.ts prüfte
-- vor dem event_participants-Insert (anders als beim analogen event_works-
-- Insert direkt darüber im selben Loop) nicht, ob die Verknüpfung schon
-- existiert. Ein erneuter Lauf für ein Event, das schon Mitwirkende hatte
-- (hier ausgelöst durch einen gezielten references_checked_at-Reset für
-- den Genre-Backfill), legte dieselbe Person/dasselbe Ensemble ein
-- zweites Mal an — sichtbar als doppelte "Mitwirkende"-Chips in der App
-- (z.B. "Anne-Sophie Mutter" zweimal, "Georg Friedrich Händel" zweimal).
-- Der Code-Fix (Existenzprüfung analog event_works) ist Teil desselben
-- Commits; diese Migration räumt die bereits entstandenen Duplikate auf
-- und ergänzt einen Unique-Index als DB-seitige Absicherung, damit das
-- strukturell nicht wieder passieren kann, egal welcher Code-Pfad schreibt.
delete from event_participants a using event_participants b
  where a.id > b.id
    and a.event_id = b.event_id
    and a.person_id is not distinct from b.person_id
    and a.ensemble_id is not distinct from b.ensemble_id;

create unique index event_participants_event_person_uniq
  on event_participants (event_id, person_id) where person_id is not null;
create unique index event_participants_event_ensemble_uniq
  on event_participants (event_id, ensemble_id) where ensemble_id is not null;
