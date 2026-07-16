import { createClient } from "@/lib/supabase/server";
import { createSource } from "../actions";
import { SourceForm } from "../source-form";

export default async function NewSourcePage() {
  const supabase = await createClient();
  const [{ data: venues }, { data: organizers }] = await Promise.all([
    supabase.from("venues").select("id, name").order("name"),
    supabase.from("organizers").select("id, name").order("name"),
  ]);

  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Neue Datenquelle</h1>
      <div className="mt-6">
        <SourceForm action={createSource} venues={venues ?? []} organizers={organizers ?? []} />
      </div>
    </div>
  );
}
