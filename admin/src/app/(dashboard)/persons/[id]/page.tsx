import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DeleteButton } from "@/components/delete-button";
import { deletePerson, updatePerson } from "../actions";
import { PersonForm, type PersonFormValues } from "../person-form";

export default async function EditPersonPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("persons")
    .select(
      "slug, full_name, roles, instrument, nationality, birth_date, death_date, biography_de, website_url, photo_url, is_verified",
    )
    .eq("id", id)
    .maybeSingle<PersonFormValues>();

  if (error || !data) notFound();

  return (
    <div className="p-8">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold tracking-tight">{data.full_name} bearbeiten</h1>
        <DeleteButton
          action={deletePerson.bind(null, id)}
          confirmMessage={`"${data.full_name}" wirklich löschen?`}
        />
      </div>
      <div className="mt-6">
        <PersonForm action={updatePerson.bind(null, id)} initial={data} />
      </div>
    </div>
  );
}
