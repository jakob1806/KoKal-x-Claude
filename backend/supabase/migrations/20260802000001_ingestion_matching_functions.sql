-- Fuzzy-Matching für die Ingestion-Pipeline (Dedupe-Engine), siehe
-- docs/06-mvp-plan.md "Ingestion-Pipeline (Basis)" und
-- docs/07-roadmap.md Phase 2. Reine "language sql"-Funktionen statt
-- plpgsql — keine RETURNS TABLE-Variablenkollisionsgefahr, siehe die
-- gleiche Entscheidung in filter_events()/similar_events() weiter oben.

-- Kandidaten für ein bereits existierendes Event am selben Venue in
-- zeitlicher Nähe, gerankt nach Titel-Trigram-Ähnlichkeit. Fenster von
-- +/-2h deckt Zeitzonen-/Rundungsabweichungen zwischen Quellen ab, ohne
-- bei täglich mehrfach bespielten Venues (z.B. zwei Konzerte am selben
-- Tag) falsch zu matchen.
create or replace function find_matching_event(
  p_title text,
  p_venue_id uuid,
  p_start_datetime timestamptz,
  p_similarity_threshold numeric default 0.35,
  p_result_limit int default 5
)
returns table (id uuid, title text, similarity numeric, start_datetime timestamptz)
language sql
stable
as $$
  select
    events.id,
    events.title,
    similarity(events.title, p_title) as similarity,
    events.start_datetime
  from events
  where events.venue_id = p_venue_id
    and events.start_datetime between p_start_datetime - interval '2 hours'
                                   and p_start_datetime + interval '2 hours'
    and similarity(events.title, p_title) >= p_similarity_threshold
  order by similarity(events.title, p_title) desc
  limit p_result_limit;
$$;

-- Fallback-Venue-Auflösung für Quellen ohne fest hinterlegte
-- sources.venue_id (z.B. ein aggregierender Feed über mehrere Spielstätten).
-- Für Quellen MIT sources.venue_id wird dies vom Ingestion-Worker
-- übersprungen — die feste Zuordnung ist immer vorrangig.
create or replace function find_matching_venue(
  p_name text,
  p_similarity_threshold numeric default 0.4,
  p_result_limit int default 3
)
returns table (id uuid, name text, similarity numeric)
language sql
stable
as $$
  select
    venues.id,
    venues.name,
    similarity(venues.name, p_name) as similarity
  from venues
  where similarity(venues.name, p_name) >= p_similarity_threshold
  order by similarity(venues.name, p_name) desc
  limit p_result_limit;
$$;
