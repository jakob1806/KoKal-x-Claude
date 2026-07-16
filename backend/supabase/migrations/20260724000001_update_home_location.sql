-- Für den Standort-Schritt im Onboarding: profiles.home_location ist
-- geography(Point,4326), PostgREST kann das nicht direkt aus lat/lng
-- schreiben (gleicher Grund wie bei create_venue/update_venue). auth.uid()
-- direkt in der Funktion statt eines expliziten user_id-Parameters — RLS
-- ("Nutzer verwaltet eigenes Profil") deckt zwar ohnehin ab, aber so kann
-- der Aufruf gar nicht erst mit einer fremden ID missbraucht werden.
create function update_home_location(p_lat float, p_lng float)
returns void
language sql
as $$
  update profiles
  set home_location = ST_MakePoint(p_lng, p_lat)::geography
  where id = auth.uid();
$$;

grant execute on function update_home_location(float, float) to authenticated;
