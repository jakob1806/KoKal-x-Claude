-- Datenintegrität: eine verstorbene Person darf nicht als LIVE AUFTRETEND
-- (Dirigent:in, Solist:in, Chorleiter:in, Moderator:in) mit einer
-- Veranstaltung verknüpft werden, die NACH ihrem Todesdatum stattfindet —
-- das ist schlicht unmöglich. Die Rolle 'komponist' ist davon ausdrücklich
-- ausgenommen: ein Werk eines längst verstorbenen Komponisten (z.B.
-- Mozart, Bach) wird ganz normal weiter aufgeführt und bleibt als
-- event_participants-Eintrag mit role='komponist' korrekt, unabhängig
-- vom Todesdatum.
--
-- Nur ein Trigger statt eines einfachen CHECK-Constraints, weil die
-- Prüfung Daten aus zwei anderen Tabellen braucht (persons.death_date,
-- events.start_datetime) — CHECK-Constraints können nur auf Spalten
-- derselben Zeile zugreifen.
create or replace function prevent_deceased_live_performer()
returns trigger
language plpgsql
as $$
declare
  v_death_date date;
  v_start_datetime timestamptz;
begin
  if new.person_id is null or new.role is null or new.role = 'komponist' then
    return new;
  end if;

  select death_date into v_death_date from persons where id = new.person_id;
  if v_death_date is null then
    return new;
  end if;

  select start_datetime into v_start_datetime from events where id = new.event_id;
  if v_start_datetime is not null and v_start_datetime::date > v_death_date then
    raise exception
      'person % ist am % verstorben und kann nicht als % (live auftretende Rolle) bei einer Veranstaltung am % verknüpft werden — nur role=komponist bleibt nach dem Tod zulässig',
      new.person_id, v_death_date, new.role, v_start_datetime;
  end if;

  return new;
end;
$$;

create trigger trg_prevent_deceased_live_performer
before insert or update on event_participants
for each row execute function prevent_deceased_live_performer();
