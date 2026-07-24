-- Voraussetzung für die automatische Bilder-Anreicherung (siehe
-- enrich-entity-images Edge Function): festivals hat schon ein photo_url-
-- Feld (siehe 20260825000001_entity_photo_uploads.sql), aber 'festival' war
-- bisher kein gültiger origin_type-Wert in images, im Gegensatz zu
-- venues/persons/ensembles.
alter table images drop constraint images_origin_type_check;
alter table images add constraint images_origin_type_check
  check (origin_type in ('event', 'venue', 'ensemble', 'person', 'organizer', 'festival'));
