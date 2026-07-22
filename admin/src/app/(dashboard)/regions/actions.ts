"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

// is_active ist das Feature-Flag, mit dem eine Stadt/ein Land für die App
// freigeschaltet wird (siehe 20260819000005_regions.sql) — Umschalten hier
// hat noch keinen App-seitigen Effekt, bis die App selbst regions.is_active
// abfragt (separater, künftiger Schritt), ist aber schon jetzt die zentrale
// Stelle, an der eine Region als "startklar" markiert wird.
export async function toggleRegionActive(regionId: string, nextActive: boolean) {
  const supabase = await createClient();

  const { error } = await supabase.from("regions").update({ is_active: nextActive }).eq("id", regionId);
  if (error) throw new Error(error.message);

  revalidatePath("/regions");
}
