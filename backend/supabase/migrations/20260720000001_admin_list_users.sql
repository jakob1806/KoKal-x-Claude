-- auth.users liegt im auth-Schema und ist bewusst nicht über PostgREST
-- exponiert (kein Zugriff über den normalen Client-Key). Für die
-- Admin-Users-Seite brauchen wir trotzdem E-Mail + Anlegedatum je Nutzer,
-- ohne dafür den Service-Role-Key im Next.js-Dashboard zu verwenden.
-- SECURITY DEFINER-RPC mit eigenem is_admin()-Check ist dafür das
-- Standard-Supabase-Pattern (vgl. handle_new_user()).
create function admin_list_users()
returns table (
  id uuid,
  email text,
  created_at timestamptz,
  display_name text,
  roles app_role[]
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'Nur Admins dürfen Nutzer auflisten';
  end if;

  return query
    select
      u.id,
      u.email::text,
      u.created_at,
      p.display_name,
      coalesce(array_agg(ur.role) filter (where ur.role is not null), '{}'::app_role[])
    from auth.users u
    left join profiles p on p.id = u.id
    left join user_roles ur on ur.user_id = u.id
    where not coalesce(u.is_anonymous, false)
    group by u.id, u.email, u.created_at, p.display_name
    order by u.created_at desc;
end;
$$;

grant execute on function admin_list_users() to authenticated;
