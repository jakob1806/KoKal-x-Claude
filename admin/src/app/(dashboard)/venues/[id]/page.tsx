import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DeleteButton } from "@/components/delete-button";
import { deleteVenue, updateVenue } from "../actions";
import { VenueForm, type VenueFormValues } from "../venue-form";

export default async function EditVenuePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const { data, error } = await supabase
    .rpc("venue_with_latlng", { p_id: id })
    .maybeSingle<VenueFormValues>();

  if (error || !data) notFound();

  return (
    <div className="p-8">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold tracking-tight">{data.name} bearbeiten</h1>
        <DeleteButton
          action={deleteVenue.bind(null, id)}
          confirmMessage={`"${data.name}" wirklich löschen? Events an diesem Ort verlieren die Ortsangabe.`}
        />
      </div>
      <div className="mt-6">
        <VenueForm action={updateVenue.bind(null, id)} initial={data} />
      </div>
    </div>
  );
}
