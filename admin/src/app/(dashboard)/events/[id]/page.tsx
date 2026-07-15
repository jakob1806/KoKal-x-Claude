import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DeleteButton } from "@/components/delete-button";
import { deleteEvent, updateEvent } from "../actions";
import { EventForm, type EventFormValues } from "../event-form";
import { loadEventFormOptions } from "../form-options";

interface EventDetailRow {
  id: string;
  slug: string;
  title: string;
  subtitle: string | null;
  description_de: string | null;
  start_datetime: string;
  duration_minutes: number | null;
  has_intermission: boolean;
  venue_id: string;
  organizer_id: string | null;
  ticket_url: string | null;
  price_min: number | null;
  price_max: number | null;
  is_free: boolean;
  status: string;
  event_genres: { genre_id: string }[];
}

export default async function EditEventPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const [{ data: event, error }, { venues, organizers, genres }] = await Promise.all([
    supabase
      .from("events")
      .select(
        "id, slug, title, subtitle, description_de, start_datetime, duration_minutes, has_intermission, venue_id, organizer_id, ticket_url, price_min, price_max, is_free, status, event_genres(genre_id)",
      )
      .eq("id", id)
      .maybeSingle<EventDetailRow>(),
    loadEventFormOptions(),
  ]);

  if (error || !event) notFound();

  const initial: EventFormValues = {
    ...event,
    genreIds: event.event_genres.map((g) => g.genre_id),
  };

  return (
    <div className="p-8">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold tracking-tight">{event.title} bearbeiten</h1>
        <DeleteButton
          action={deleteEvent.bind(null, id)}
          confirmMessage={`"${event.title}" wirklich löschen?`}
        />
      </div>
      <div className="mt-6">
        <EventForm
          action={updateEvent.bind(null, id)}
          initial={initial}
          venues={venues}
          organizers={organizers}
          genres={genres}
        />
      </div>
    </div>
  );
}
