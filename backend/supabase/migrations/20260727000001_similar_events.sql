-- "Ähnliche Veranstaltungen" auf EventDetail, siehe docs/05-navigation-structure.md
-- und docs/07-roadmap.md Phase 5 ("zunächst regelbasiert aus Phase 1").
-- Regelbasiert: gleiches (erstes) Genre ODER gleiche Venue, kommend,
-- exklusive des Events selbst. language sql statt plpgsql, weil reines
-- SELECT ohne Kontrollfluss auskommt — vermeidet damit von vornherein die
-- Ambiguous-id-Falle aus filter_events() (RETURNS TABLE-Spaltennamen als
-- implizite PL/pgSQL-Variablen gibt es hier nicht).
create function similar_events(
  p_event_id uuid,
  p_genre_id uuid default null,
  p_venue_id uuid default null,
  p_result_limit int default 6
)
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
language sql
stable
as $$
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
  where e.status = 'scheduled'
    and e.id != p_event_id
    and e.start_datetime >= now()
    and (
      (p_genre_id is not null and exists (
        select 1 from event_genres eg where eg.event_id = e.id and eg.genre_id = p_genre_id
      ))
      or (p_venue_id is not null and e.venue_id = p_venue_id)
    )
  order by e.start_datetime
  limit p_result_limit;
$$;

grant execute on function similar_events(uuid, uuid, uuid, int) to anon, authenticated;
