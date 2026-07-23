-- Architektur-Dokument Abschnitt 2.2/11: Embeddings für semantische
-- Empfehlungen — die pgvector-Extension und events.embedding vector(1536)
-- standen seit der allerersten Migration bereit ("Embeddings für
-- Empfehlungen (Phase 3)"), wurden aber nie befüllt oder indiziert.
-- similar_events() (20260727000001) ist bewusst weiterhin regelbasiert
-- (gleiches Genre/gleiche Venue) — siehe deren eigener Kommentar
-- "zunächst regelbasiert aus Phase 1". Diese Migration ergänzt eine
-- SEPARATE, additive Funktion statt die bestehende zu ersetzen; die App
-- auf die semantische Variante umzustellen ist ein bewusst nicht in dieser
-- Migration enthaltener, eigener Schritt (siehe Kommentar unten).
--
-- 1536 -> 768: der gewählte Embedding-Provider (Gemini text-embedding-004,
-- siehe _shared/ai/embeddings.ts) liefert 768-dimensionale Vektoren, nicht
-- 1536 (das war vermutlich für OpenAI-Embeddings vorgesehen, das aber nie
-- Teil des Providerkreises wurde). Die Spalte war noch nie befüllt
-- (durchweg null), ein ALTER TYPE ist deshalb ohne Datenverlust möglich.
--
-- events_today/events_this_weekend/events_free (20260715000014_views.sql)
-- sind "select * from events"-Views und hängen dadurch an JEDER
-- events-Spalte, auch embedding — Postgres verweigert ALTER COLUMN TYPE,
-- solange eine View die Spalte referenziert. Drop + Recreate mit exakt
-- denselben Definitionen wie im Original ist hier sicher (reine
-- "select * from events where ..."-Views ohne eigene Berechnung/Indizes).
drop view if exists events_today;
drop view if exists events_this_weekend;
drop view if exists events_free;

alter table events alter column embedding type vector(768);

create index events_embedding_hnsw_idx on events using hnsw (embedding vector_cosine_ops);

-- Additiv zu similar_events() (regelbasiert) — nutzt Cosinus-Distanz statt
-- Genre/Venue-Übereinstimmung. Nur Events mit bereits berechnetem Embedding
-- kommen infrage; ein Event ohne Embedding liefert einfach keine
-- semantischen Treffer (kein Fehler).
create function find_similar_events_by_embedding(
  p_event_id uuid,
  p_result_limit int default 6
)
returns table (
  id uuid,
  slug text,
  title text,
  distance float
)
language sql
stable
as $$
  select
    e.id, e.slug, e.title,
    e.embedding <=> (select embedding from events where id = p_event_id) as distance
  from events e
  where e.status = 'scheduled'
    and e.id != p_event_id
    and e.start_datetime >= now()
    and e.embedding is not null
    and (select embedding from events where id = p_event_id) is not null
  order by e.embedding <=> (select embedding from events where id = p_event_id)
  limit p_result_limit;
$$;

grant execute on function find_similar_events_by_embedding(uuid, int) to anon, authenticated;

create view events_today as
select * from events
where status = 'scheduled'
  and start_datetime::date = (now() at time zone 'Europe/Berlin')::date;

create view events_this_weekend as
select * from events
where status = 'scheduled'
  and start_datetime >= date_trunc('week', now() at time zone 'Europe/Berlin') + interval '5 days'
  and start_datetime < date_trunc('week', now() at time zone 'Europe/Berlin') + interval '8 days';

create view events_free as
select * from events
where status = 'scheduled' and is_free = true;
