// Gemeinsame Typen für die AI-Provider-Abstraktion (siehe router.ts). Ein
// AiFunctionDeclaration ist Standard-JSON-Schema (type-Werte kleingeschrieben,
// z.B. "object"/"string"/"array"; Optionalität einfach über Weglassen aus
// `required` statt eines herstellerspezifischen `nullable`-Felds) — jeder
// Provider übersetzt das bei Bedarf in sein eigenes Format (siehe
// providers/gemini.ts für ein Beispiel, das eine Übersetzung braucht).

export interface AiFunctionDeclaration {
  name: string;
  description: string;
  // deno-lint-ignore no-explicit-any
  parameters: Record<string, any>;
}

export interface AiProvider {
  name: string;
  /** Name des Supabase-Secrets, das diesen Provider aktiviert. */
  envKey: string;
  /** Liefert die geparsten Funktionsargumente zurück, oder null bei jedem
   * Fehler (fehlender Key, Netzwerkfehler, Kontingent erschöpft, kein
   * Tool-Call in der Antwort) — der Router behandelt null einheitlich als
   * "weiter zum nächsten Provider", ohne zwischen den Fehlerursachen zu
   * unterscheiden. */
  callFunction(
    system: string,
    user: string,
    fn: AiFunctionDeclaration,
    // deno-lint-ignore no-explicit-any
  ): Promise<Record<string, any> | null>;
}
