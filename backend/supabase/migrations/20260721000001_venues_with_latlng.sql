-- Für den Karten-Tab: alle Venues auf einmal mit lat/lng (PostgREST liefert
-- geography-Spalten sonst als WKB-Hex) plus Anzahl kommender Events, damit
-- die Vorschau-Sheet-Kachel ohne Zusatz-Query etwas Sinnvolles anzeigen kann.
-- Öffentlich lesbar wie search_all — die Karte ist ohne Login nutzbar.
create function venues_with_latlng()
returns table (
  id uuid,
  slug text,
  name text,
  address_city text,
  lat float,
  lng float,
  upcoming_event_count bigint
)
language sql
stable
as $$
  select
    v.id, v.slug, v.name, v.address_city,
    ST_Y(v.location::geometry) as lat,
    ST_X(v.location::geometry) as lng,
    count(e.id) filter (
      where e.status = 'scheduled' and e.start_datetime >= now()
    ) as upcoming_event_count
  from venues v
  left join events e on e.venue_id = v.id
  group by v.id, v.slug, v.name, v.address_city, v.location;
$$;

grant execute on function venues_with_latlng() to anon, authenticated;
