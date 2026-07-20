-- 20260814000001 hat recommended_events() versehentlich auf die alte
-- Funktionsversion (aus 20260729) zurückgesetzt, die profile_interest_venues
-- und profile_interest_persons referenziert -- beide Tabellen wurden aber
-- schon in 20260801_use_existing_favorite_tables.sql absichtlich gedroppt
-- und durch user_favorite_venues/user_favorite_persons/user_favorite_ensembles
-- ersetzt. Ergebnis: "relation profile_interest_venues does not exist" bei
-- jedem Aufruf, Home-Screen konnte keine Events mehr laden.
-- Diese Migration stellt die Logik aus 20260801 wieder her (inkl.
-- Ensemble-Boost und "Venue besucht"-Signal über event_views) und behält
-- die image_urls-Spalte aus 20260814000001.
create or replace function recommended_events(p_result_limit int default 10)
returns table (
  id uuid,
  slug text,
  title text,
  subtitle text,
  is_free boolean,
  remaining_tickets_status text,
  start_datetime timestamptz,
  venue_id uuid,
  venues jsonb,
  event_genres jsonb,
  image_urls text[]
)
language plpgsql
stable
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
begin
  return query
    select
      e.id, e.slug, e.title, e.subtitle, e.is_free, e.remaining_tickets_status, e.start_datetime,
      v.id,
      jsonb_build_object('name', v.name),
      coalesce(
        (
          select jsonb_agg(jsonb_build_object('genres', jsonb_build_object('slug', g.slug)))
          from event_genres eg
          join genres g on g.id = eg.genre_id
          where eg.event_id = e.id
        ),
        '[]'::jsonb
      ),
      e.image_urls
    from events e
    join venues v on v.id = e.venue_id
    where e.status = 'scheduled' and e.start_datetime >= now()
    order by
      (
        -- Genre-Interesse
        (case when v_uid is not null and exists (
          select 1 from event_genres eg
          join profile_interest_genres pig on pig.genre_id = eg.genre_id
          where eg.event_id = e.id and pig.user_id = v_uid
        ) then 5 else 0 end)
        +
        -- Venue-Interesse ODER Venue schon besucht
        (case when v_uid is not null and (
          exists (
            select 1 from user_favorite_venues ufv
            where ufv.venue_id = e.venue_id and ufv.user_id = v_uid
          )
          or exists (
            select 1 from event_views ev
            join events e2 on e2.id = ev.event_id
            where e2.venue_id = e.venue_id and ev.user_id = v_uid
          )
        ) then 3 else 0 end)
        +
        -- Komponist/Mitwirkende-Interesse (Personen)
        (case when v_uid is not null and exists (
          select 1 from event_participants ep
          join user_favorite_persons ufp on ufp.person_id = ep.person_id
          where ep.event_id = e.id and ufp.user_id = v_uid
        ) then 4 else 0 end)
        +
        -- Ensemble-Interesse
        (case when v_uid is not null and exists (
          select 1 from event_participants ep
          join user_favorite_ensembles ufe on ufe.ensemble_id = ep.ensemble_id
          where ep.event_id = e.id and ufe.user_id = v_uid
        ) then 4 else 0 end)
        +
        -- Popularität (Anzahl Favorisierungen)
        (select count(*)::float * 0.5 from favorites f where f.event_id = e.id)
        -
        -- zeitliche Nähe: Events weiter in der Zukunft leicht abgewertet
        (extract(epoch from (e.start_datetime - now())) / 86400.0 / 30.0)
      ) desc,
      e.start_datetime
    limit p_result_limit;
end;
$$;
