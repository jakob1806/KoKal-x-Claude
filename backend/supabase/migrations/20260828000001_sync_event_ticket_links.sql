-- ticket_providers/event_ticket_links (20260819000008) waren seit ihrer
-- Einführung komplett unbenutztes Schema — events.ticket_url wird bis
-- heute ausschließlich manuell im Admin-Eventformular gepflegt
-- (admin/src/app/(dashboard)/events/actions.ts), nichts schrieb je in
-- ticket_providers/event_ticket_links. Diese Migration schließt die Lücke
-- rein auf DB-Ebene: ein Trigger auf events leitet bei jedem
-- Insert/Update aus ticket_url automatisch den Anbieter (per Domain) her,
-- legt bei Bedarf eine neue ticket_providers-Zeile an und hält
-- event_ticket_links synchron. Additiv und ohne jede Anwendungscode-
-- Änderung: Admin/App kennen weiterhin nur events.ticket_url, das bleibt
-- die Quelle der Wahrheit; ticket_providers/event_ticket_links füllen
-- sich automatisch daraus und werden erst nutzbar (Buchungsgebühren-
-- Hinweise, Auswertung "welcher Anbieter") wenn/falls dafür später eine
-- eigene Admin-Ansicht gebaut wird.
--
-- Aktuell existiert pro Event nur EIN ticket_url, deshalb hält der Trigger
-- event_ticket_links als 1:1-Spiegel (alte Zeilen mit abweichender URL
-- werden entfernt) statt mehrerer Anbieter pro Event zu unterstützen — die
-- Tabelle selbst kann das schon (mehrere Zeilen pro event_id), das wäre
-- ein rein additiver nächster Schritt, sobald tatsächlich mehrere
-- Verkaufsstellen pro Event erfasst werden sollen.
create or replace function sync_event_ticket_link() returns trigger
language plpgsql
as $$
declare
  v_domain text;
  v_provider_id uuid;
begin
  -- ticket_url gelöscht/geleert -> alle Links dieses Events entfernen.
  if new.ticket_url is null then
    delete from event_ticket_links where event_id = new.id;
    return new;
  end if;

  -- Host aus der URL extrahieren (ohne Schema/www-Präfix), z.B.
  -- "https://www.muenchenticket.de/foo" -> "muenchenticket.de".
  v_domain := lower(regexp_replace(new.ticket_url, '^(?:https?://)?(?:www\.)?([^/]+).*$', '\1'));
  if v_domain = '' or v_domain = new.ticket_url then
    -- Konnte keinen Host extrahieren (kaputte/ungewöhnliche URL) -> nichts
    -- Sinnvolles zu verknüpfen, alte Links dieses Events trotzdem aufräumen.
    delete from event_ticket_links where event_id = new.id;
    return new;
  end if;

  insert into ticket_providers (name, domain)
    values (v_domain, v_domain)
    on conflict (domain) do nothing;
  select id into v_provider_id from ticket_providers where domain = v_domain;

  -- Alte Links mit abweichender URL entfernen (1:1-Spiegel, siehe oben),
  -- dann den aktuellen upserten.
  delete from event_ticket_links where event_id = new.id and url is distinct from new.ticket_url;
  insert into event_ticket_links (event_id, ticket_provider_id, url, price_min, price_max, currency)
    values (new.id, v_provider_id, new.ticket_url, new.price_min, new.price_max, coalesce(new.price_currency, 'EUR'))
    on conflict (event_id, url) do update set
      ticket_provider_id = excluded.ticket_provider_id,
      price_min = excluded.price_min,
      price_max = excluded.price_max,
      currency = excluded.currency;

  return new;
end;
$$;

drop trigger if exists trg_sync_event_ticket_link on events;
create trigger trg_sync_event_ticket_link
  after insert or update of ticket_url, price_min, price_max, price_currency on events
  for each row execute function sync_event_ticket_link();

-- Backfill für bereits bestehende Events mit gesetztem ticket_url.
do $$
declare
  r record;
begin
  for r in select id, ticket_url, price_min, price_max, price_currency from events where ticket_url is not null
  loop
    update events set ticket_url = r.ticket_url where id = r.id;
  end loop;
end $$;
