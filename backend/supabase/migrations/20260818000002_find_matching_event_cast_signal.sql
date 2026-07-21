-- Erweitert find_matching_event() um ein optionales Besetzungs-Signal
-- (p_cast_names) — zwei Quellen können dieselbe Veranstaltung mit
-- unterschiedlichem Titelwortlaut melden ("Klavierabend" vs. "Igor Levit
-- spielt Beethoven"); reine Titel-Trigram-Ähnlichkeit kann das verpassen.
-- Additiv und rückwärtskompatibel: ohne Angabe (default null) verhält sich
-- die Funktion exakt wie zuvor. Wirkt in der Praxis erst, sobald das
-- kandidierende Event bereits event_participants hat (z.B. durch
-- enrich-event-references) — bis dahin liefert der Besetzungs-Bonus 0 und
-- similarity entspricht weiterhin der reinen Titel-Ähnlichkeit.
create or replace function find_matching_event(
  p_title text,
  p_venue_id uuid,
  p_start_datetime timestamptz,
  p_similarity_threshold numeric default 0.35,
  p_result_limit int default 5,
  p_cast_names text[] default null
)
returns table (id uuid, title text, similarity numeric, start_datetime timestamptz)
language sql
stable
as $$
  with candidates as (
    select
      events.id,
      events.title,
      similarity(events.title, p_title) as title_similarity,
      events.start_datetime
    from events
    where events.venue_id = p_venue_id
      and events.start_datetime between p_start_datetime - interval '2 hours'
                                     and p_start_datetime + interval '2 hours'
  ),
  scored as (
    select
      c.id,
      c.title,
      c.start_datetime,
      -- Bonus von bis zu 0.15, proportional zur besten Namens-Ähnlichkeit
      -- zwischen einem übergebenen Besetzungsnamen und einer/einem bereits
      -- verknüpften Mitwirkenden (Person oder Ensemble) dieses Kandidaten.
      least(1.0, c.title_similarity + 0.15 * coalesce((
        select max(similarity(pn.name, cn))
        from unnest(coalesce(p_cast_names, '{}'::text[])) as cn
        cross join lateral (
          select p.full_name as name
          from event_participants ep
          join persons p on p.id = ep.person_id
          where ep.event_id = c.id
          union all
          select e.name
          from event_participants ep
          join ensembles e on e.id = ep.ensemble_id
          where ep.event_id = c.id
        ) pn
      ), 0)) as similarity
    from candidates c
  )
  select id, title, similarity, start_datetime
  from scored
  where similarity >= p_similarity_threshold
  order by similarity desc
  limit p_result_limit;
$$;
