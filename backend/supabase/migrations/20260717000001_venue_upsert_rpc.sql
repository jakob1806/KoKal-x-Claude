-- RPCs fürs Admin-Dashboard: nehmen lat/lng als floats entgegen und wandeln
-- sie serverseitig in geography(Point,4326) um. Vermeidet, dass der Next.js-
-- Client WKT/GeoJSON für PostGIS-Spalten über PostgREST serialisieren muss.
-- security invoker (Standard) — läuft als der aufrufende Nutzer, RLS auf
-- venues (is_admin_or_editor()) greift also ganz normal weiter.

create function create_venue(
  p_slug text,
  p_name text,
  p_description_de text,
  p_address_street text,
  p_address_zip text,
  p_address_city text,
  p_lat float,
  p_lng float,
  p_capacity int,
  p_website_url text
)
returns venues
language plpgsql
as $$
declare
  v venues;
begin
  insert into venues (
    slug, name, description_de, address_street, address_zip, address_city,
    location, capacity, website_url
  )
  values (
    p_slug, p_name, p_description_de, p_address_street, p_address_zip,
    coalesce(p_address_city, 'München'), ST_MakePoint(p_lng, p_lat)::geography,
    p_capacity, p_website_url
  )
  returning * into v;
  return v;
end;
$$;

create function update_venue(
  p_id uuid,
  p_slug text,
  p_name text,
  p_description_de text,
  p_address_street text,
  p_address_zip text,
  p_address_city text,
  p_lat float,
  p_lng float,
  p_capacity int,
  p_website_url text
)
returns venues
language plpgsql
as $$
declare
  v venues;
begin
  update venues set
    slug = p_slug,
    name = p_name,
    description_de = p_description_de,
    address_street = p_address_street,
    address_zip = p_address_zip,
    address_city = coalesce(p_address_city, address_city),
    location = ST_MakePoint(p_lng, p_lat)::geography,
    capacity = p_capacity,
    website_url = p_website_url,
    updated_at = now()
  where id = p_id
  returning * into v;
  return v;
end;
$$;

-- Für die Bearbeiten-Formulare: lat/lng aus geography zurück extrahieren
-- (PostgREST liefert geography-Spalten sonst als WKB-Hex, nicht direkt nutzbar).
create function venue_with_latlng(p_id uuid)
returns table (
  id uuid, slug text, name text, description_de text,
  address_street text, address_zip text, address_city text,
  lat float, lng float, capacity int, website_url text
)
language sql
stable
as $$
  select
    v.id, v.slug, v.name, v.description_de,
    v.address_street, v.address_zip, v.address_city,
    ST_Y(v.location::geometry) as lat, ST_X(v.location::geometry) as lng,
    v.capacity, v.website_url
  from venues v
  where v.id = p_id;
$$;
