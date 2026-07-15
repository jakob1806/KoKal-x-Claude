import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * Aktualisiert die Supabase-Session innerhalb von proxy.ts (Next.js 16 —
 * ehemals middleware.ts). Muss auf einer echten NextRequest/NextResponse
 * arbeiten statt auf next/headers' cookies(), da Proxy vor dem Rendering
 * läuft.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // getUser() statt getSession(): validiert den Token gegen den Auth-Server
  // statt nur das (fälschbare) Cookie zu lesen.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return { response, user, supabase };
}
