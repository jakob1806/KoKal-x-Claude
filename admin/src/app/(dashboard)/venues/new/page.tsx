import { createVenue } from "../actions";
import { VenueForm } from "../venue-form";

export default function NewVenuePage() {
  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Neue Venue</h1>
      <div className="mt-6">
        <VenueForm action={createVenue} />
      </div>
    </div>
  );
}
