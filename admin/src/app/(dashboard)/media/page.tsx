export default function MediaPage() {
  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Bilder</h1>
      <p className="mt-1 max-w-xl text-sm text-neutral-500">
        Bildupload und -zuordnung zu Events, Venues und Personen (Supabase Storage).
      </p>
      <div className="mt-6 rounded-lg border border-dashed border-neutral-300 bg-white px-4 py-10 text-center text-sm text-neutral-400">
        Folgt in Phase 1 (siehe docs/06-mvp-plan.md, Admin-Dashboard).
      </div>
    </div>
  );
}
