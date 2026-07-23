import type { SupabaseClient } from "@supabase/supabase-js";

// Schreibt einen Audit-Log-Eintrag (Architektur-Dokument Abschnitt 10,
// system_logs siehe 20260819000006_system_logs.sql). Best-effort: ein
// Logging-Fehler soll die eigentliche redaktionelle Aktion nie zum
// Scheitern bringen — nur in die Server-Konsole geloggt, nicht geworfen.
export async function logSystemAction(
  supabase: SupabaseClient,
  params: {
    entityType: string;
    entityId: string | null;
    action: string;
    actor: string;
    before?: unknown;
    after?: unknown;
  },
) {
  const { error } = await supabase.from("system_logs").insert({
    entity_type: params.entityType,
    entity_id: params.entityId,
    action: params.action,
    actor: params.actor,
    before: params.before ?? null,
    after: params.after ?? null,
  });
  if (error) console.error(`logSystemAction (${params.entityType}/${params.action}): ${error.message}`);
}
