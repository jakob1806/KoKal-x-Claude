export interface ExtractResult {
  status: "success" | "failed" | "idle";
  extractionMethod?: "schema_org" | "llm";
  eventsFound?: number;
  eventsCreated?: number;
  eventsUpdated?: number;
  eventsFlaggedForReview?: number;
  results?: Array<{ title: string; outcome: string; error?: string }>;
  errors?: string[];
  error?: string;
}

export const INITIAL_STATE: ExtractResult = { status: "idle" };
