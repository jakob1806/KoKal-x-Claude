"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { logSystemAction } from "@/lib/system-log";

export async function deleteTag(tagId: string) {
  const supabase = await createClient();

  const { error } = await supabase.from("tags").delete().eq("id", tagId);
  if (error) throw new Error(error.message);

  const { data: { user } } = await supabase.auth.getUser();
  await logSystemAction(supabase, {
    entityType: "tag",
    entityId: tagId,
    action: "deleted",
    actor: user?.email ?? user?.id ?? "unknown",
  });

  revalidatePath("/tags");
}
