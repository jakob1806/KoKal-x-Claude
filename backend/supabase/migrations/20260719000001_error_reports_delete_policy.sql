-- error_reports hatte bisher nur eine select-Policy für Redaktion — RLS
-- verweigert ohne passende Policy alles andere per Default, auch für Admins.
-- Das Reports-Dashboard braucht "als erledigt entfernen", siehe
-- admin/src/app/(dashboard)/reports/actions.ts.
create policy "Redaktion löscht Fehlerberichte" on error_reports for delete using (is_admin_or_editor());
