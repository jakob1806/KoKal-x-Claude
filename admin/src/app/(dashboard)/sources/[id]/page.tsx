import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DeleteButton } from "@/components/delete-button";
import { deleteSource, updateSource } from "../actions";
import { SourceForm, type SourceFormValues } from "../source-form";

export default async function EditSourcePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data, error }, { data: venues }, { data: organizers }] = await Promise.all([
    supabase
      .from("sources")
      .select("name, type, url, venue_id, organizer_id, crawl_frequency_minutes, legal_basis, status")
      .eq("id", id)
      .maybeSingle<SourceFormValues>(),
    supabase.from("venues").select("id, name").order("name"),
    supabase.from("organizers").select("id, name").order("name"),
  ]);

  if (error || !data) notFound();

  return (
    <div className="p-8">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold tracking-tight">{data.name} bearbeiten</h1>
        <DeleteButton action={deleteSource.bind(null, id)} confirmMessage={`"${data.name}" wirklich löschen?`} />
      </div>
      <div className="mt-6">
        <SourceForm action={updateSource.bind(null, id)} initial={data} venues={venues ?? []} organizers={organizers ?? []} />
      </div>
    </div>
  );
}
