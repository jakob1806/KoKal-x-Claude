"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function readSourceFields(formData: FormData) {
  return {
    name: String(formData.get("name") ?? "").trim(),
    type: String(formData.get("type") ?? "manual"),
    url: String(formData.get("url") ?? "").trim(),
    venue_id: String(formData.get("venue_id") ?? "") || null,
    organizer_id: String(formData.get("organizer_id") ?? "") || null,
    crawl_frequency_minutes: Number(formData.get("crawl_frequency_minutes") ?? 1440),
    legal_basis: String(formData.get("legal_basis") ?? "").trim() || null,
    status: String(formData.get("status") ?? "active"),
  };
}

export async function createSource(formData: FormData) {
  const f = readSourceFields(formData);
  const supabase = await createClient();
  const { error } = await supabase.from("sources").insert(f);
  if (error) throw new Error(error.message);

  revalidatePath("/sources");
  redirect("/sources");
}

export async function updateSource(sourceId: string, formData: FormData) {
  const f = readSourceFields(formData);
  const supabase = await createClient();
  const { error } = await supabase.from("sources").update(f).eq("id", sourceId);
  if (error) throw new Error(error.message);

  revalidatePath("/sources");
  redirect("/sources");
}

export async function deleteSource(sourceId: string) {
  const supabase = await createClient();
  const { error } = await supabase.from("sources").delete().eq("id", sourceId);
  if (error) throw new Error(error.message);

  revalidatePath("/sources");
  redirect("/sources");
}
