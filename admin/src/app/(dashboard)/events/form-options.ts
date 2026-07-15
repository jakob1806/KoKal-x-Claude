import { createClient } from "@/lib/supabase/server";

export async function loadEventFormOptions() {
  const supabase = await createClient();
  const [{ data: venues }, { data: organizers }, { data: genres }] = await Promise.all([
    supabase.from("venues").select("id, name").order("name"),
    supabase.from("organizers").select("id, name").order("name"),
    supabase.from("genres").select("id, label_de").order("sort_order"),
  ]);

  return {
    venues: venues ?? [],
    organizers: organizers ?? [],
    genres: genres ?? [],
  };
}
