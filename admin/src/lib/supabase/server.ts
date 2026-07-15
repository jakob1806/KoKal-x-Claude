import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/**
 * Supabase-Client für Server Components / Route Handlers.
 * Nutzt den Service-Role-Key NICHT — Redakteure authentifizieren sich
 * über normale Supabase-Auth-Sessions, Rechte laufen über RLS
 * (`is_admin_or_editor()`, siehe backend/supabase/migrations/..._row_level_security.sql).
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Aufruf aus einer Server Component ohne Schreibzugriff auf Cookies — ignorierbar,
            // solange Middleware die Session ansonsten aktuell hält.
          }
        },
      },
    },
  );
}
