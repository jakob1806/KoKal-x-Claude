-- Ersetzt die trending_searches materialized view (Phase 0, nie befüllt —
-- keine Refresh-Infrastruktur existierte) durch eine SECURITY DEFINER-
-- Funktion. Ein Grund, warum eine einfache View nicht reicht: search_history
-- hat RLS auf auth.uid() = user_id ("Nutzer sieht eigene Suchhistorie"),
-- eine normale View würde also nur die Suchhistorie des aufrufenden Nutzers
-- aggregieren statt eine echte nutzerübergreifende Trend-Liste zu liefern.
-- SECURITY DEFINER umgeht das bewusst — es werden nur aggregierte Zähler pro
-- Suchbegriff offengelegt, keine Nutzeridentitäten oder Einzel-Historien.
-- Als Funktion statt materialisierter View außerdem immer aktuell, ganz
-- ohne pg_cron/Scheduling-Infrastruktur — bei MVP-Datenmenge (siehe
-- docs/06-mvp-plan.md: "≥ 300 Veranstaltungen zum Launch") ist die Live-
-- Aggregation trivial günstig; falls search_history mal groß genug wird,
-- dass das nicht mehr stimmt, ist eine materialisierte + geplante Variante
-- der naheliegende nächste Schritt.
drop materialized view if exists trending_searches;

create function trending_searches(p_result_limit int default 10)
returns table (query text, search_count bigint)
language sql
security definer
set search_path = public
stable
as $$
  select query, count(*) as search_count
  from search_history
  where created_at > now() - interval '7 days'
  group by query
  order by search_count desc
  limit p_result_limit;
$$;

grant execute on function trending_searches(int) to anon, authenticated;
