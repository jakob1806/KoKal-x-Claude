"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function dismissReport(reportId: number) {
  const supabase = await createClient();
  const { error } = await supabase.from("error_reports").delete().eq("id", reportId);
  if (error) throw new Error(error.message);

  revalidatePath("/reports");
}
