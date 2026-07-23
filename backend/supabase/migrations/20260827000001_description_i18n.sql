-- Architektur-Dokument Abschnitt 12: i18n-Umbau bewusst FRÜH einplanen
-- (nicht erst bei Bedarf), auch wenn zunächst nur {"de": "..."} befüllt
-- ist — der Grund ist genau der, den das Dokument nennt: description_de
-- -> description_i18n ist ein Breaking Change für jeden Reader (Flutter-
-- App, Admin-Formulare), und das JETZT nachzuholen, wenn eine zweite
-- Sprache tatsächlich ansteht, wäre die teure Variante.
--
-- Diese Migration ist bewusst NICHT der Breaking Change selbst, sondern
-- bereitet ihn vor: description_i18n/biography_i18n werden ADDITIV
-- ergänzt, description_de/biography_de bleiben unverändert die von
-- App/Admin gelesene und beschriebene Quelle. Ein Trigger hält
-- description_i18n->>'de' automatisch synchron mit description_de bei
-- jedem Insert/Update — kein Anwendungscode (Flutter-App, Next.js-Admin,
-- Ingestion-Pipeline) muss sich für diese Migration ändern. Der eigentliche
-- Cutover (App/Admin lesen/schreiben description_i18n direkt, ggf. mit
-- Sprachauswahl) ist ein separater, späterer Schritt, sobald eine zweite
-- Sprache tatsächlich gebraucht wird — dann ist das Schema aber schon da.
create or replace function sync_description_i18n() returns trigger
language plpgsql
as $$
begin
  new.description_i18n := coalesce(new.description_i18n, '{}'::jsonb);
  if new.description_de is not null then
    new.description_i18n := jsonb_set(new.description_i18n, '{de}', to_jsonb(new.description_de));
  else
    new.description_i18n := new.description_i18n - 'de';
  end if;
  return new;
end;
$$;

create or replace function sync_biography_i18n() returns trigger
language plpgsql
as $$
begin
  new.biography_i18n := coalesce(new.biography_i18n, '{}'::jsonb);
  if new.biography_de is not null then
    new.biography_i18n := jsonb_set(new.biography_i18n, '{de}', to_jsonb(new.biography_de));
  else
    new.biography_i18n := new.biography_i18n - 'de';
  end if;
  return new;
end;
$$;

-- description_de-Tabellen: venues, organizers, ensembles, works, events,
-- festivals. persons hat stattdessen biography_de (andere Semantik: Bio
-- statt Beschreibung), separat unten behandelt.
do $$
declare
  t text;
begin
  foreach t in array array['venues', 'organizers', 'ensembles', 'works', 'events', 'festivals']
  loop
    execute format('alter table %I add column if not exists description_i18n jsonb', t);
    execute format(
      $sql$update %I set description_i18n = jsonb_build_object('de', description_de) where description_de is not null and (description_i18n is null or not (description_i18n ? 'de'))$sql$,
      t
    );
    execute format(
      'drop trigger if exists trg_sync_description_i18n on %I; create trigger trg_sync_description_i18n before insert or update on %I for each row execute function sync_description_i18n();',
      t, t
    );
  end loop;
end $$;

alter table persons add column if not exists biography_i18n jsonb;
update persons set biography_i18n = jsonb_build_object('de', biography_de)
  where biography_de is not null and (biography_i18n is null or not (biography_i18n ? 'de'));
drop trigger if exists trg_sync_biography_i18n on persons;
create trigger trg_sync_biography_i18n before insert or update on persons
  for each row execute function sync_biography_i18n();
