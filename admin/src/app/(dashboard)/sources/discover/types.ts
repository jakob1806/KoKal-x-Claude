export interface DiscoverResult {
  status: "idle" | "ok" | "failed";
  query?: string;
  candidatesFound?: number;
  created?: number;
  skippedKnown?: number;
  skippedDuplicatePending?: number;
  note?: string;
  error?: string;
}

export const INITIAL_STATE: DiscoverResult = { status: "idle" };
