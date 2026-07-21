-- Fuzzy-Matching für Personen/Ensembles (Architektur-Dokument Abschnitt 2.3)
-- — bisher matcht enrich-event-references nur exakt case-insensitive
-- (bewusst so, um keine unterschiedlichen Personen versehentlich
-- zusammenzulegen), wodurch z.B. "Symphonieorchester des Bayerischen
-- Rundfunks" vs. "Symphonieorchester des BR" oder Tippfehler in
-- Quellentexten unnötig neue entity_candidates statt eines Treffers
-- erzeugen. Analog zu find_matching_venue/find_matching_event
-- (20260802000001_ingestion_matching_functions.sql), gleiches
-- language-sql-Muster.
--
-- WICHTIG: diese Funktionen liefern nur Kandidaten zurück — die
-- Entscheidung "automatisch verknüpfen vs. nur als Hinweis an
-- entity_candidates anhängen" bleibt in der Anwendungsschicht
-- (enrich-event-references/index.ts), nicht hier. Grund: zwei
-- unterschiedliche Personen desselben Namens sind real (z.B. mehrere
-- "Michael Schmidt" als Kirchenmusiker) — automatisches Zusammenführen
-- allein aufgrund von SQL-Ähnlichkeit ist riskanter als bei Venues/Events,
-- wo Fehlzuordnungen leichter auffallen.

create or replace function find_matching_person(
  p_name text,
  p_similarity_threshold numeric default 0.5,
  p_result_limit int default 3
)
returns table (id uuid, full_name text, similarity numeric)
language sql
stable
as $$
  select
    persons.id,
    persons.full_name,
    similarity(persons.full_name, p_name) as similarity
  from persons
  where similarity(persons.full_name, p_name) >= p_similarity_threshold
  order by similarity(persons.full_name, p_name) desc
  limit p_result_limit;
$$;

create or replace function find_matching_ensemble(
  p_name text,
  p_similarity_threshold numeric default 0.5,
  p_result_limit int default 3
)
returns table (id uuid, name text, similarity numeric)
language sql
stable
as $$
  select
    ensembles.id,
    ensembles.name,
    similarity(ensembles.name, p_name) as similarity
  from ensembles
  where similarity(ensembles.name, p_name) >= p_similarity_threshold
  order by similarity(ensembles.name, p_name) desc
  limit p_result_limit;
$$;
