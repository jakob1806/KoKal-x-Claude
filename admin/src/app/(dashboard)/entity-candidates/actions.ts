"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { logSystemAction } from "@/lib/system-log";

export interface ResolveWithAiResult {
  status: "ok" | "failed";
  processed?: number;
  approved?: number;
  leftPending?: number;
  errors?: string[];
  error?: string;
}

// Ruft die resolve-entity-candidates Edge Function auf: Batch-Nachlauf für
// bereits wartende Kandidaten, die nie durch die automatische Entscheidung
// in enrich-event-references liefen (die gilt nur für neu erkannte Namen ab
// ihrer Einführung — Nutzer-Feedback: "ich muss immer noch alles selbst
// freigeben", weil die bestehende Warteliste davon unberührt blieb).
export async function resolveEntityCandidatesWithAi(): Promise<ResolveWithAiResult> {
  const baseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  let res: Response;
  try {
    res = await fetch(`${baseUrl}/functions/v1/resolve-entity-candidates`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: anonKey ?? "",
        Authorization: `Bearer ${anonKey ?? ""}`,
      },
      body: JSON.stringify({}),
    });
  } catch (err) {
    return {
      status: "failed",
      error: `resolve-entity-candidates nicht erreichbar: ${err instanceof Error ? err.message : String(err)}`,
    };
  }

  let body: Record<string, unknown>;
  try {
    body = await res.json();
  } catch {
    return { status: "failed", error: `Unerwartete Antwort (HTTP ${res.status}).` };
  }

  if (!res.ok || body.error) {
    return { status: "failed", error: (body.error as string) ?? `HTTP ${res.status}` };
  }

  revalidatePath("/entity-candidates");

  return {
    status: "ok",
    processed: body.processed as number | undefined,
    approved: body.approved as number | undefined,
    leftPending: body.left_pending as number | undefined,
    errors: body.errors as string[] | undefined,
  };
}

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

  const { data: { user } } = await supabase.auth.getUser();
  await logSystemAction(supabase, {
    entityType: "entity_candidate",
    entityId: candidateId,
    action: "rejected",
    actor: user?.email ?? user?.id ?? "unknown",
  });

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

  const { data: { user } } = await supabase.auth.getUser();
  await logSystemAction(supabase, {
    entityType: "entity_candidate",
    entityId: candidateId,
    action: "approved_created",
    actor: user?.email ?? user?.id ?? "unknown",
    after: { [createdIdColumn]: newId, name: candidate.name },
  });

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

  const { data: { user } } = await supabase.auth.getUser();
  await logSystemAction(supabase, {
    entityType: "entity_candidate",
    entityId: candidateId,
    action: "merged",
    actor: user?.email ?? user?.id ?? "unknown",
    after: { [createdIdColumn]: matchedEntityId },
  });

  revalidatePath("/entity-candidates");
}
