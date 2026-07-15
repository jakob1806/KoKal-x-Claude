import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DeleteButton } from "@/components/delete-button";
import { deleteEnsemble, updateEnsemble } from "../actions";
import { EnsembleForm, type EnsembleFormValues } from "../ensemble-form";

export default async function EditEnsemblePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data, error }, { data: venues }] = await Promise.all([
    supabase
      .from("ensembles")
      .select(
        "slug, name, type, description_de, founded_year, member_count, home_venue_id, website_url, photo_url, is_verified",
      )
      .eq("id", id)
      .maybeSingle<EnsembleFormValues>(),
    supabase.from("venues").select("id, name").order("name"),
  ]);

  if (error || !data) notFound();

  return (
    <div className="p-8">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold tracking-tight">{data.name} bearbeiten</h1>
        <DeleteButton
          action={deleteEnsemble.bind(null, id)}
          confirmMessage={`"${data.name}" wirklich löschen?`}
        />
      </div>
      <div className="mt-6">
        <EnsembleForm action={updateEnsemble.bind(null, id)} initial={data} venues={venues ?? []} />
      </div>
    </div>
  );
}
