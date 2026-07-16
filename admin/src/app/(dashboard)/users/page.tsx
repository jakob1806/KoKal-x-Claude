import { createClient } from "@/lib/supabase/server";
import { AssignRoleForm, RoleBadge } from "./user-roles-cell";

export const dynamic = "force-dynamic";

interface AdminUserRow {
  id: string;
  email: string;
  created_at: string;
  display_name: string | null;
  roles: string[];
}

export default async function UsersPage() {
  const supabase = await createClient();
  const [
    {
      data: { user: currentUser },
    },
    { data: rawData, error },
  ] = await Promise.all([supabase.auth.getUser(), supabase.rpc("admin_list_users")]);
  const data = rawData as AdminUserRow[] | null;

  return (
    <div className="p-8">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Benutzer</h1>
        <p className="mt-1 max-w-xl text-sm text-neutral-500">
          Admins verwalten Inhalte uneingeschränkt und können Rollen vergeben; Redakteure bearbeiten Inhalte, aber keine
          Nutzerrechte. Anonyme App-Sessions werden hier nicht aufgeführt.
        </p>
      </div>

      {error && <p className="mt-6 text-sm text-amber-700">Konnte Nutzer nicht laden: {error.message}</p>}

      {!error && (
        <div className="mt-6 overflow-hidden rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500">
              <tr>
                <th className="px-4 py-3 font-medium">Nutzer</th>
                <th className="px-4 py-3 font-medium">Rollen</th>
                <th className="px-4 py-3 font-medium">Registriert</th>
                <th className="px-4 py-3 font-medium">Rolle zuweisen</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {data?.length ? (
                data.map((u) => (
                  <tr key={u.id} className="hover:bg-neutral-50">
                    <td className="px-4 py-3">
                      <p className="font-medium text-neutral-900">
                        {u.display_name || u.email}
                        {u.id === currentUser?.id && (
                          <span className="ml-2 rounded-full bg-neutral-100 px-2 py-0.5 text-xs font-normal text-neutral-500">
                            Du
                          </span>
                        )}
                      </p>
                      {u.display_name && <p className="text-xs text-neutral-500">{u.email}</p>}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap items-center gap-1.5">
                        {u.roles.length ? (
                          u.roles.map((role) => <RoleBadge key={role} userId={u.id} role={role} />)
                        ) : (
                          <span className="text-xs text-neutral-400">Keine Rolle</span>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-neutral-600 tabular-nums">
                      {new Date(u.created_at).toLocaleDateString("de-DE", { dateStyle: "medium" })}
                    </td>
                    <td className="px-4 py-3">
                      <AssignRoleForm userId={u.id} existingRoles={u.roles} />
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={4} className="px-4 py-10 text-center text-neutral-400">
                    Noch keine Nutzer registriert.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
