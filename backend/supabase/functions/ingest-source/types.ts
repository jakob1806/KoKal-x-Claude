// Gemeinsamer Vertrag zwischen den Connectoren (parsers/*.ts) und dem
// Orchestrator (index.ts) — jeder Connector normalisiert Quellformat-
// spezifische Daten (Schema.org/iCal/RSS) auf dieselbe Form, damit
// Matching/Dedupe/Write-Logik formatunabhängig bleiben.

export interface RawEvent {
  /** Stabile ID aus der Quelle, falls vorhanden (z.B. iCal UID) — noch
   * nicht für Matching genutzt, aber für spätere Idempotenz vorgesehen. */
  externalId: string | null;
  title: string;
  description: string | null;
  /** ISO 8601 */
  startDateTime: string;
  /** ISO 8601 — null wenn die Quelle keine Endzeit liefert. */
  endDateTime: string | null;
  /** Freitext-Venue-Name aus der Quelle, für find_matching_venue() wenn
   * die Source keine feste venue_id hat. */
  venueName: string | null;
  venueAddress: string | null;
  url: string | null;
  imageUrl: string | null;
  priceMin: number | null;
  priceMax: number | null;
  isFree: boolean | null;
}

export interface ParseResult {
  events: RawEvent[];
  /** Nicht-fatale Parse-Fehler pro Item — sammeln statt werfen, damit ein
   * kaputter Eintrag nicht den ganzen Lauf abbricht. */
  errors: string[];
}
