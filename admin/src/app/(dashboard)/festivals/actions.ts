"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { logSystemAction } from "@/lib/system-log";

export async function createFestival(formData: FormData) {
  const supabase = await createClient();

  const payload = {
    name: String(formData.get("name") ?? "").trim(),
    slug: String(formData.get("slug") ?? "").trim(),
    description_de: String(formData.get("description_de") ?? "").trim() || null,
    organizer_id: String(formData.get("organizer_id") ?? "").trim() || null,
    recurring: formData.get("recurring") === "on",
    website_url: String(formData.get("website_url") ?? "").trim() || null,
  };

  const { data, error } = await supabase.from("festivals").insert(payload).select("id").single();
  if (error) throw new Error(error.message);

  const { data: { user } } = await supabase.auth.getUser();
  await logSystemAction(supabase, {
    entityType: "festival",
    entityId: data.id,
    action: "created",
    actor: user?.email ?? user?.id ?? "unknown",
    after: payload,
  });

  revalidatePath("/festivals");
  redirect("/festivals");
}
