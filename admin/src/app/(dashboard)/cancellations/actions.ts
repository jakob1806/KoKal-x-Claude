"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

// Ein cancellation_candidates-Eintrag heißt: das Event war in einem
// früheren Ingestion-Lauf der Quelle vorhanden, fehlt aber im aktuellen
// Lauf (siehe backend/supabase/functions/ingest-source/index.ts,
// flagMissingEvents()). "Bestätigen" heißt: die Redaktion hat geprüft, dass
// die Veranstaltung tatsächlich abgesagt wurde — setzt event.status direkt
// auf 'cancelled'. "Ablehnen" heißt: false positive (Quelle war z.B. nur
// vorübergehend unvollständig) — Event bleibt unverändert 'scheduled'.
export async function confirmCancellation(candidateId: string) {
  const supabase = await createClient();

  const { data: candidate, error: fetchError } = await supabase
    .from("cancellation_candidates")
    .select("event_id")
    .eq("id", candidateId)
    .maybeSingle();

  if (fetchError || !candidate) {
    throw new Error(fetchError?.message ?? "Absage-Kandidat nicht gefunden");
  }

  const { error: eventError } = await supabase
    .from("events")
    .update({ status: "cancelled" })
    .eq("id", candidate.event_id);
  if (eventError) throw new Error(eventError.message);

  const { error: updateError } = await supabase
    .from("cancellation_candidates")
    .update({ status: "confirmed", reviewed_at: new Date().toISOString() })
    .eq("id", candidateId);
  if (updateError) throw new Error(updateError.message);

  revalidatePath("/cancellations");
}

export async function dismissCancellation(candidateId: string) {
  const supabase = await createClient();

  const { error } = await supabase
    .from("cancellation_candidates")
    .update({ status: "dismissed", reviewed_at: new Date().toISOString() })
    .eq("id", candidateId);
  if (error) throw new Error(error.message);

  revalidatePath("/cancellations");
}
