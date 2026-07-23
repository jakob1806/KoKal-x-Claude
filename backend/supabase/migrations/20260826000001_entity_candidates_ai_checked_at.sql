-- Behebt einen echten Starvation-Bug in resolve-entity-candidates: die
-- Auswahl sortierte bisher nur nach created_at aufsteigend, ohne zu
-- vermerken, welche Kandidaten schon per KI geprüft (aber unklar
-- geblieben) waren. Ein paar dauerhaft ambivalente Kandidaten am Anfang
-- der Warteliste (z.B. mit possible_match) blockierten dadurch für immer
-- die Verarbeitung ALLER neueren Kandidaten dahinter — jeder Klick auf
-- "Mit KI prüfen" holte immer wieder dieselben paar unklaren Namen, nie
-- die Kandidaten weiter hinten in der Liste.
alter table entity_candidates add column ai_last_checked_at timestamptz;

-- Für die "noch nie geprüft zuerst, dann am längsten nicht geprüft"-
-- Sortierung in resolve-entity-candidates/index.ts.
create index idx_entity_candidates_ai_check_order
  on entity_candidates (ai_last_checked_at nulls first, created_at)
  where status = 'pending';
