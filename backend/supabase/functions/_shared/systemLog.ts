// Schreibt Einträge in system_logs (Architektur-Dokument Abschnitt 10:
// Audit-Log für automatisierte Änderungen an Stammdaten — Fuzzy-Auto-Links,
// Merges, automatische Freigaben). Best-effort: ein Fehlschlag hier darf nie
// den eigentlichen Pipeline-Schritt scheitern lassen, deshalb wird nur
// geloggt, nie geworfen. Läuft mit dem service_role-Key der aufrufenden
// Function und umgeht damit die RLS-Insert-Policy (is_admin_or_editor()),
// die nur für Clients mit anon/redaktionellem Key gilt.
export async function logSystemAction(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  entityType: string,
  entityId: string | null,
  action: string,
  details: Record<string, unknown>,
  actor = "system",
): Promise<void> {
  const { error } = await supabase.from("system_logs").insert({
    entity_type: entityType,
    entity_id: entityId,
    action,
    actor,
    after: details,
  });
  if (error) {
    console.error(`logSystemAction ${entityType}/${action}: ${error.message}`);
  }
}
