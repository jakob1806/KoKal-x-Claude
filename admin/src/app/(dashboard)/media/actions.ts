"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { logSystemAction } from "@/lib/system-log";

// license_status-Übergänge sind bewusst redaktionelle Entscheidungen, nie
// automatisch (siehe 20260819000003_images_and_tags.sql) — needs_review
// wird hier explizit auf false gesetzt, sobald ein Redakteur eine
// Entscheidung getroffen hat (egal ob frei, lizenziert oder abgelehnt).
async function setLicenseStatus(imageId: string, status: "confirmed_free" | "confirmed_licensed" | "rejected") {
  const supabase = await createClient();

  const { error } = await supabase
    .from("images")
    .update({ license_status: status, needs_review: false })
    .eq("id", imageId);
  if (error) throw new Error(error.message);

  const { data: { user } } = await supabase.auth.getUser();
  await logSystemAction(supabase, {
    entityType: "image",
    entityId: imageId,
    action: `license_${status}`,
    actor: user?.email ?? user?.id ?? "unknown",
  });

  revalidatePath("/media");
}

export async function confirmImageFree(imageId: string) {
  await setLicenseStatus(imageId, "confirmed_free");
}

export async function confirmImageLicensed(imageId: string) {
  await setLicenseStatus(imageId, "confirmed_licensed");
}

export async function rejectImage(imageId: string) {
  await setLicenseStatus(imageId, "rejected");
}
