-- Materialisierte Views & Views, siehe docs/02-database-schema.md §13
create materialized view trending_searches as
select query, count(*) as search_count
from search_history
where created_at > now() - interval '7 days'
group by query
order by search_count desc
limit 20;

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
