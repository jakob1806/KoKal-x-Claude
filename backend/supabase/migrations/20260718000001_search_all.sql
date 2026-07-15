-- Volltextsuche über Postgres (pg_trgm), siehe docs/02-database-schema.md.
-- Bewusst kein Meilisearch für den ersten Wurf: die nötigen Indizes
-- (gin_trgm_ops auf Namen/Titeln) existieren bereits seit Phase 0, das
-- deckt MVP-Suchvolumen ab. Meilisearch bleibt als spätere Option, falls
-- Datenmenge oder Facetten-UX es rechtfertigen (siehe docs/01-architecture.md).
--
-- ILIKE-Substring-Matching statt reinem `%`-Ähnlichkeitsoperator, damit auch
-- sehr kurze Eingaben (2-3 Zeichen, "Suche während des Tippens") zuverlässig
-- treffen — pg_trgm beschleunigt ILIKE '%...%' über denselben GIN-Index.
create or replace function search_all(q text, result_limit int default 8)
returns table (
  result_type text,
  id uuid,
  slug text,
  title text,
  subtitle text,
  score real
)
language sql
stable
as $$
  with pattern as (select '%' || trim(q) || '%' as p, trim(q) as raw)
  (
    select 'event'::text, e.id, e.slug, e.title,
           v.name || ' · ' || to_char(e.start_datetime at time zone 'Europe/Berlin', 'DD.MM.YYYY'),
           similarity(e.title, pattern.raw)
    from events e
    join venues v on v.id = e.venue_id
    cross join pattern
    where e.status != 'draft'
      and (e.title ilike pattern.p or e.subtitle ilike pattern.p)
    order by 6 desc
    limit result_limit
  )
  union all
  (
    select 'person', p.id, p.slug, p.full_name,
           array_to_string(p.roles::text[], ', '),
           similarity(p.full_name, pattern.raw)
    from persons p cross join pattern
    where p.full_name ilike pattern.p
    order by 6 desc
    limit result_limit
  )
  union all
  (
    select 'ensemble', en.id, en.slug, en.name, en.type::text,
           similarity(en.name, pattern.raw)
    from ensembles en cross join pattern
    where en.name ilike pattern.p
    order by 6 desc
    limit result_limit
  )
  union all
  (
    select 'venue', ve.id, ve.slug, ve.name, ve.address_city,
           similarity(ve.name, pattern.raw)
    from venues ve cross join pattern
    where ve.name ilike pattern.p
    order by 6 desc
    limit result_limit
  )
  order by 6 desc;
$$;

grant execute on function search_all(text, int) to anon, authenticated;
