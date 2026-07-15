export default function DuplicatesPage() {
  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Duplikate-Review</h1>
      <p className="mt-1 max-w-xl text-sm text-neutral-500">
        Kandidaten aus dem Fuzzy-Matching der Ingestion-Pipeline bestätigen oder verwerfen.
      </p>
      <div className="mt-6 rounded-lg border border-dashed border-neutral-300 bg-white px-4 py-10 text-center text-sm text-neutral-400">
        Folgt in Phase 1 (siehe docs/06-mvp-plan.md, Admin-Dashboard).
      </div>
    </div>
  );
}
