"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function markEventVerified(eventId: string) {
  const supabase = await createClient();
  const { error } = await supabase
    .from("events")
    .update({ last_verified_at: new Date().toISOString() })
    .eq("id", eventId);
  if (error) throw new Error(error.message);

  revalidatePath("/data-quality");
}
