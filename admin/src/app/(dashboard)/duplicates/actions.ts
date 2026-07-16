"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

// event_b_id ist im Ingestion-Worker (backend/supabase/functions/ingest-
// source/write.ts) immer das neu angelegte Draft-Event, event_a_id immer
// das bereits existierende, gegen das es gematcht wurde — siehe
// upsertRawEvent()'s duplicate_candidates-Insert. "Zusammenführen" behält
// deshalb immer event_a und löscht event_b, nie umgekehrt.
export async function resolveDuplicateAsMerged(candidateId: string) {
  const supabase = await createClient();

  const { data: candidate, error: fetchError } = await supabase
    .from("duplicate_candidates")
    .select("event_b_id")
    .eq("id", candidateId)
    .maybeSingle();

  if (fetchError || !candidate) {
    throw new Error(fetchError?.message ?? "Duplikate-Kandidat nicht gefunden");
  }

  const { error: updateError } = await supabase
    .from("duplicate_candidates")
    .update({ status: "merged", reviewed_at: new Date().toISOString() })
    .eq("id", candidateId);
  if (updateError) throw new Error(updateError.message);

  const { error: deleteError } = await supabase.from("events").delete().eq("id", candidate.event_b_id);
  if (deleteError) throw new Error(deleteError.message);

  revalidatePath("/duplicates");
}

export async function resolveDuplicateAsDistinct(candidateId: string) {
  const supabase = await createClient();

  const { error } = await supabase
    .from("duplicate_candidates")
    .update({ status: "dismissed", reviewed_at: new Date().toISOString() })
    .eq("id", candidateId);
  if (error) throw new Error(error.message);

  revalidatePath("/duplicates");
}
