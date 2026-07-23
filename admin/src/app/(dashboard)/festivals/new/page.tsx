import { createClient } from "@/lib/supabase/server";
import { createFestival } from "../actions";
import { FestivalForm } from "../festival-form";

export default async function NewFestivalPage() {
  const supabase = await createClient();
  const { data: organizers } = await supabase.from("organizers").select("id, name").order("name");

  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Neues Festival</h1>
      <div className="mt-6">
        <FestivalForm action={createFestival} organizers={organizers ?? []} />
      </div>
    </div>
  );
}
