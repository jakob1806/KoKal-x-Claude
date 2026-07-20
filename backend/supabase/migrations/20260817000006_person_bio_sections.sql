-- Erweitert Personen-Profile um strukturierte Bio-Abschnitte, siehe
-- Nutzer-Feedback "Bios der Künstler sind viel zu kurz". Bewusst als jsonb-
-- Arrays statt eigener Tabellen: jeder Eintrag wird immer nur im Kontext
-- einer einzelnen Person gelesen/angezeigt, nie tabellenübergreifend
-- gefiltert oder verknüpft (anders als z.B. event_participants) — passt
-- damit zum bestehenden Muster von social_links jsonb, nicht zum Muster
-- von event_works/event_participants.
--
-- Struktur pro Array-Element:
--   awards:                {"year": int|null, "title": text, "note": text|null}
--   notable_recordings:    {"year": int|null, "title": text, "label": text|null, "url": text|null}
--   repertoire_highlights: {"title": text, "note": text|null}
-- Reihenfolge im Array = Anzeigereihenfolge (kein separates sort_order-Feld
-- nötig für die paar erwarteten Einträge pro Person).
alter table persons
  add column awards jsonb not null default '[]',
  add column notable_recordings jsonb not null default '[]',
  add column repertoire_highlights jsonb not null default '[]';
