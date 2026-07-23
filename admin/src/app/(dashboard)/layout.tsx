import { Sidebar } from "@/components/sidebar";
import { SignOutButton } from "@/components/sign-out-button";
import { createClient } from "@/lib/supabase/server";

export default async function DashboardLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <div className="flex min-h-full">
      <Sidebar userEmail={user?.email} />
      <main className="flex-1 min-w-0 bg-white text-neutral-900">
        <div className="flex justify-end border-b border-neutral-200 bg-white px-8 py-3">
          <SignOutButton />
        </div>
        {children}
      </main>
    </div>
  );
}
