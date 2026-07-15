-- Auth-Bootstrap: automatisches Profil bei Signup + erster echter Nutzer wird Admin.
-- Läuft als SECURITY DEFINER, umgeht damit die RLS-Policies auf profiles/user_roles
-- (die für normale Nutzer nur den eigenen Datensatz erlauben) — Standard-Supabase-Pattern.
create function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into profiles (id, display_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  -- Anonyme Sessions (Supabase Anonymous Auth) zählen nicht für den
  -- Admin-Bootstrap, sonst würde der erstbeste App-Öffner zum Admin.
  if not coalesce(new.is_anonymous, false)
     and not exists (select 1 from user_roles where role = 'admin') then
    insert into user_roles (user_id, role) values (new.id, 'admin');
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
