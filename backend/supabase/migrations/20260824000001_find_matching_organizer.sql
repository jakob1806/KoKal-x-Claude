-- Ergänzt find_matching_person/find_matching_ensemble
-- (20260819000002) um Organizer — gebraucht von der neuen
-- discover-sources-Function (Architektur-Dokument Abschnitt 9: eigene
-- Function statt in enrich-event-references mitzulaufen), um zu prüfen, ob
-- ein per Websuche gefundener Veranstalter bereits als organizer bekannt
-- ist, bevor er als entity_candidate vorgeschlagen wird.
create or replace function find_matching_organizer(
  p_name text,
  p_similarity_threshold numeric default 0.5,
  p_result_limit int default 3
)
returns table (id uuid, name text, similarity numeric)
language sql
stable
as $$
  select
    organizers.id,
    organizers.name,
    similarity(organizers.name, p_name) as similarity
  from organizers
  where similarity(organizers.name, p_name) >= p_similarity_threshold
  order by similarity(organizers.name, p_name) desc
  limit p_result_limit;
$$;
