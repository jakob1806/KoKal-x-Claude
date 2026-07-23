-- Redaktion soll Fotos für Venues/Ensembles/Festivals/Personen selbst als
-- Datei hochladen können (statt nur eine externe URL einzutragen) — die
-- Datei landet im neuen "entity-photos"-Storage-Bucket, die öffentliche URL
-- wird wie bisher in *.photo_url gespeichert. Bucket ist public=true (die
-- App zeigt diese Bilder ohnehin öffentlich an), Schreibzugriff über
-- storage.objects-RLS auf is_admin_or_editor() beschränkt.

-- festivals hatte bisher keine photo_url-Spalte (persons/venues/ensembles
-- schon, siehe 20260715000003/5/6) — nachgezogen für Konsistenz.
alter table festivals add column photo_url text;

create policy "Redaktion lädt Entity-Fotos hoch" on storage.objects
  for insert
  with check (bucket_id = 'entity-photos' and is_admin_or_editor());

create policy "Redaktion aktualisiert Entity-Fotos" on storage.objects
  for update
  using (bucket_id = 'entity-photos' and is_admin_or_editor())
  with check (bucket_id = 'entity-photos' and is_admin_or_editor());

create policy "Redaktion löscht Entity-Fotos" on storage.objects
  for delete
  using (bucket_id = 'entity-photos' and is_admin_or_editor());

-- venues hatte photo_url in der DB, aber weder im Admin-Formular noch in
-- den create_venue/update_venue-RPCs (20260717000001) — als zusätzlicher
-- Parameter MIT Default angehängt, damit die bestehende Signatur (und alle
-- bestehenden Aufrufer) unverändert kompatibel bleiben.
create or replace function create_venue(
  p_slug text,
  p_name text,
  p_description_de text,
  p_address_street text,
  p_address_zip text,
  p_address_city text,
  p_lat float,
  p_lng float,
  p_capacity int,
  p_website_url text,
  p_photo_url text default null
)
returns venues
language plpgsql
as $$
declare
  v venues;
begin
  insert into venues (
    slug, name, description_de, address_street, address_zip, address_city,
    location, capacity, website_url, photo_url
  )
  values (
    p_slug, p_name, p_description_de, p_address_street, p_address_zip,
    coalesce(p_address_city, 'München'), ST_MakePoint(p_lng, p_lat)::geography,
    p_capacity, p_website_url, p_photo_url
  )
  returning * into v;
  return v;
end;
$$;

create or replace function update_venue(
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
  p_website_url text,
  p_photo_url text default null
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
    photo_url = p_photo_url,
    updated_at = now()
  where id = p_id
  returning * into v;
  return v;
end;
$$;

-- returns table()-Signatur ändert sich (neue Spalte) — braucht expliziten
-- Drop, "create or replace" allein lehnt Änderungen am OUT-Zeilentyp ab.
drop function if exists venue_with_latlng(uuid);

create function venue_with_latlng(p_id uuid)
returns table (
  id uuid, slug text, name text, description_de text,
  address_street text, address_zip text, address_city text,
  lat float, lng float, capacity int, website_url text, photo_url text
)
language sql
stable
as $$
  select
    v.id, v.slug, v.name, v.description_de,
    v.address_street, v.address_zip, v.address_city,
    ST_Y(v.location::geometry) as lat, ST_X(v.location::geometry) as lng,
    v.capacity, v.website_url, v.photo_url
  from venues v
  where v.id = p_id;
$$;
