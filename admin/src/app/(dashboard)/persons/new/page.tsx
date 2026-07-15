import { createPerson } from "../actions";
import { PersonForm } from "../person-form";

export default function NewPersonPage() {
  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Neue Person</h1>
      <div className="mt-6">
        <PersonForm action={createPerson} />
      </div>
    </div>
  );
}
