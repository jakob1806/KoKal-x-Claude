-- Architektur-Dokument Abschnitt 2.2: Ticketanbieter als eigene Entität
-- statt nur events.ticket_url (Freitext-URL, kein strukturierter Bezug zum
-- Anbieter selbst — z.B. für Buchungsgebühren-Hinweise oder späteres
-- Filtern/Auswerten "welcher Anbieter verkauft die meisten Tickets" nicht
-- nutzbar). Rein additiv, events.ticket_url bleibt unverändert bestehen.
create table ticket_providers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  domain text not null unique,
  booking_fee_notes text,
  created_at timestamptz not null default now()
);
alter table ticket_providers enable row level security;
create policy "Ticketanbieter sind öffentlich lesbar" on ticket_providers for select using (true);
create policy "Redaktion verwaltet Ticketanbieter" on ticket_providers for all using (is_admin_or_editor()) with check (is_admin_or_editor());

create table event_ticket_links (
  event_id uuid not null references events(id) on delete cascade,
  ticket_provider_id uuid references ticket_providers(id),
  url text not null,
  price_min numeric,
  price_max numeric,
  currency text not null default 'EUR',
  primary key (event_id, url)
);
create index event_ticket_links_event_idx on event_ticket_links (event_id);
alter table event_ticket_links enable row level security;
create policy "Ticket-Links sind öffentlich lesbar" on event_ticket_links for select using (true);
create policy "Redaktion verwaltet Ticket-Links" on event_ticket_links for all using (is_admin_or_editor()) with check (is_admin_or_editor());
