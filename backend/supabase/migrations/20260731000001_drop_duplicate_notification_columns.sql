-- Behebt eine Doppelung: notification_preferences existierte schon seit
-- Phase 0 als eigene Tabelle (mit RLS-Policy "Nutzer verwaltet eigene
-- Benachrichtigungseinstellungen") für exakt diesen Zweck, wurde aber beim
-- Bauen der Benachrichtigungseinstellungen übersehen — stattdessen wurden
-- vier neue notify_*-Spalten auf profiles angelegt. Keine Nutzerdaten
-- betroffen (beide Speicherorte leer bzw. nur Default-Werte, vor dem Dropp
-- geprüft), daher direktes drop statt Datenmigration.
alter table profiles
  drop column notify_new_matching_events,
  drop column notify_price_changes,
  drop column notify_almost_sold_out,
  drop column notify_reminder_day_before;
