import { createEvent } from "../actions";
import { EventForm } from "../event-form";
import { loadEventFormOptions } from "../form-options";

export default async function NewEventPage() {
  const { venues, organizers, genres } = await loadEventFormOptions();

  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Neue Veranstaltung</h1>
      <div className="mt-6">
        <EventForm action={createEvent} venues={venues} organizers={organizers} genres={genres} />
      </div>
    </div>
  );
}
