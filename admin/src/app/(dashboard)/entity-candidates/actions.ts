"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

// Slugify hier dupliziert statt aus den Deno-Functions importiert — die
// Admin-App (Next.js) und die Edge Functions (Deno) teilen keinen
// Modul-Raum, dieselbe kleine Funktion existiert auch in
// backend/supabase/functions/ingest-source/write.ts und
// enrich-event-references/index.ts.
function slugify(title: string): string {
  const umlauts: Record<string, string> = { ä: "ae", ö: "oe", ü: "ue", ß: "ss", Ä: "ae", Ö: "oe", Ü: "ue" };
  let s = title;
  for (const [from, to] of Object.entries(umlauts)) s = s.split(from).join(to);
  s = s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80)
    .replace(/-+$/g, "");
  return s || "eintrag";
}

export async function rejectEntityCandidate(candidateId: string) {
  const supabase = await createClient();

  const { error } = await supabase
    .from("entity_candidates")
    .update({ status: "rejected", reviewed_at: new Date().toISOString() })
    .eq("id", candidateId);
  if (error) throw new Error(error.message);

  revalidatePath("/entity-candidates");
}

// Legt die echte persons/ensembles/organizers-Zeile an (is_verified: false —
// unterscheidet sich bewusst von einer handkuratierten Stammdaten-Zeile),
// verlinkt den Kandidaten damit und markiert ihn als 'approved'. Verknüpft
// NICHT automatisch mit einem Event — das passiert erst, wenn eine echte
// Quelle (ingest-source) das Event tatsächlich einliest und dabei die neue
// Person/das neue Ensemble findet.
export async function approveEntityCandidate(candidateId: string) {
  const supabase = await createClient();

  const { data: candidate, error: fetchError } = await supabase
    .from("entity_candidates")
    .select("entity_type, name")
    .eq("id", candidateId)
    .maybeSingle();
  if (fetchError || !candidate) {
    throw new Error(fetchError?.message ?? "Kandidat nicht gefunden");
  }

  const slug = slugify(candidate.name);
  let createdIdColumn: "created_person_id" | "created_ensemble_id" | "created_organizer_id";
  let newId: string;

  if (candidate.entity_type === "person") {
    const { data, error } = await supabase
      .from("persons")
      .insert({ full_name: candidate.name, slug, is_verified: false })
      .select("id")
      .single();
    if (error || !data) throw new Error(error?.message ?? "persons insert fehlgeschlagen");
    newId = data.id;
    createdIdColumn = "created_person_id";
  } else if (candidate.entity_type === "ensemble") {
    const { data, error } = await supabase
      .from("ensembles")
      .insert({ name: candidate.name, slug, type: "sonstiges", is_verified: false })
      .select("id")
      .single();
    if (error || !data) throw new Error(error?.message ?? "ensembles insert fehlgeschlagen");
    newId = data.id;
    createdIdColumn = "created_ensemble_id";
  } else {
    const { data, error } = await supabase
      .from("organizers")
      .insert({ name: candidate.name, slug })
      .select("id")
      .single();
    if (error || !data) throw new Error(error?.message ?? "organizers insert fehlgeschlagen");
    newId = data.id;
    createdIdColumn = "created_organizer_id";
  }

  const { error: updateError } = await supabase
    .from("entity_candidates")
    .update({ status: "approved", reviewed_at: new Date().toISOString(), [createdIdColumn]: newId })
    .eq("id", candidateId);
  if (updateError) throw new Error(updateError.message);

  revalidatePath("/entity-candidates");
}

// Für Kandidaten mit einem discovery_context.possible_match (Fuzzy-Match
// aus find_matching_person/find_matching_ensemble, siehe
// 20260722000002_find_matching_person_ensemble.sql): verlinkt den Kandidaten
// mit der BEREITS VORHANDENEN Person/dem Ensemble statt einen neuen
// Stammdaten-Eintrag anzulegen. Legt bewusst NICHTS in persons/ensembles an.
export async function mergeEntityCandidate(candidateId: string, matchedEntityId: string) {
  const supabase = await createClient();

  const { data: candidate, error: fetchError } = await supabase
    .from("entity_candidates")
    .select("entity_type")
    .eq("id", candidateId)
    .maybeSingle();
  if (fetchError || !candidate) {
    throw new Error(fetchError?.message ?? "Kandidat nicht gefunden");
  }
  if (candidate.entity_type !== "person" && candidate.entity_type !== "ensemble") {
    throw new Error(`Zusammenführen nur für person/ensemble unterstützt, nicht "${candidate.entity_type}"`);
  }

  const createdIdColumn = candidate.entity_type === "person" ? "created_person_id" : "created_ensemble_id";
  const { error: updateError } = await supabase
    .from("entity_candidates")
    .update({ status: "approved", reviewed_at: new Date().toISOString(), [createdIdColumn]: matchedEntityId })
    .eq("id", candidateId);
  if (updateError) throw new Error(updateError.message);

  revalidatePath("/entity-candidates");
}
