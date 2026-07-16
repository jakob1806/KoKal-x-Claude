-- Ergänzt den Venue-Boost in recommended_events() um "besucht", nicht nur
-- "favorisiert" — docs/06-mvp-plan.md: "Nutzer hat Venue X favorisiert/
-- besucht (via event_views) → Boost für weitere Events an Venue X". Der
-- explizite Interesse-Boost war schon da, event_views wurde aber nirgends
-- geschrieben oder gelesen. Client-seitiges Tracking kommt zusammen mit
-- dieser Migration (EventDetailScreen).
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
  event_genres jsonb
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
      )
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
            select 1 from profile_interest_venues piv
            where piv.venue_id = e.venue_id and piv.user_id = v_uid
          )
          or exists (
            select 1 from event_views ev
            join events e2 on e2.id = ev.event_id
            where e2.venue_id = e.venue_id and ev.user_id = v_uid
          )
        ) then 3 else 0 end)
        +
        -- Komponist/Mitwirkende-Interesse
        (case when v_uid is not null and exists (
          select 1 from event_participants ep
          join profile_interest_persons pip on pip.person_id = ep.person_id
          where ep.event_id = e.id and pip.user_id = v_uid
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
