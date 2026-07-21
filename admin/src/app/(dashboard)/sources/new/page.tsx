import { createClient } from "@/lib/supabase/server";
import { createSource } from "../actions";
import { SourceForm } from "../source-form";

export default async function NewSourcePage() {
  const supabase = await createClient();
  const [{ data: venues }, { data: organizers }, { data: persons }, { data: ensembles }] = await Promise.all([
    supabase.from("venues").select("id, name").order("name"),
    supabase.from("organizers").select("id, name").order("name"),
    supabase.from("persons").select("id, full_name").order("full_name"),
    supabase.from("ensembles").select("id, name").order("name"),
  ]);

  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Neue Datenquelle</h1>
      <div className="mt-6">
        <SourceForm
          action={createSource}
          venues={venues ?? []}
          organizers={organizers ?? []}
          persons={persons ?? []}
          ensembles={ensembles ?? []}
        />
      </div>
    </div>
  );
}
