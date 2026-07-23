export interface ProbePreviewItem {
  title: string;
  startDateTime: string;
  venueName: string | null;
  isFree: boolean | null;
}

export interface ProbeResult {
  status: "idle" | "ok" | "ok_manual_only" | "no_events_found" | "failed" | "blocked";
  url?: string;
  recommendedType?: "schema_org" | "ical" | "rss" | null;
  eventsFound?: number;
  preview?: ProbePreviewItem[];
  message?: string;
  error?: string;
  errors?: string[];
}

export const INITIAL_STATE: ProbeResult = { status: "idle" };
