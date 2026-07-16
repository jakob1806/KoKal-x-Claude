-- Benachrichtigungseinstellungen, siehe docs/06-mvp-plan.md §"Push-Benachrichtigungen".
-- Feste, kleine Menge an Umschaltern statt jsonb-Spalte — vier bekannte
-- Typen, kein dynamisch erweiterbares Set, also lieber typisiert als
-- jsonb-Keys, bei denen ein Tippfehler im Client stillschweigend ignoriert würde.
-- Default true (Opt-out), da Push ohnehin erst nach expliziter
-- Systemberechtigung ankommt (siehe core/push/push_service.dart).
alter table profiles
  add column notify_new_matching_events boolean not null default true,
  add column notify_price_changes boolean not null default true,
  add column notify_almost_sold_out boolean not null default true,
  add column notify_reminder_day_before boolean not null default true;
