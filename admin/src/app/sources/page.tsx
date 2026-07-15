export default function SourcesPage() {
  return (
    <div className="p-8">
      <h1 className="text-xl font-semibold tracking-tight">Datenquellen & Import</h1>
      <p className="mt-1 max-w-xl text-sm text-neutral-500">
        Schema.org-, iCal- und RSS-Quellen verwalten, Import-Läufe einsehen und manuell anstoßen.
      </p>
      <div className="mt-6 rounded-lg border border-dashed border-neutral-300 bg-white px-4 py-10 text-center text-sm text-neutral-400">
        Folgt in Phase 2 (siehe docs/07-roadmap.md, Ingestion-Pipeline).
      </div>
    </div>
  );
}
