-- Herkulessaal und Allerheiligen-Hofkirche (beide residenz-muenchen.de,
-- Migrationen 20260807000001/20260808000001) zeigten bisher nur Seite 1
-- ihrer Suchergebnisse — dokumentierte, bewusst nicht behobene Lücke aus
-- PR #35 (Herkulessaal: "nur Seite 1 von 2, 10 von 17 Treffern"). Jetzt
-- behoben: neue nextPageSelector-Config + Paginierungs-Loop in index.ts
-- (siehe dort). residenz-muenchen.de hat keine vorhersagbare Seitenzahl-
-- URL-Systematik (Seite 1 des Herkulessaal-Suchergebnisses nutzt PN=6,
-- Seite 2 PN=2 — kein arithmetischer Zusammenhang), daher wird der
-- "nächste Seite"-Link pro Seite aus dem HTML gelesen statt eine Ziel-URL
-- zu berechnen. a[title="weiter zur nächsten Seite"] ist eindeutig (live
-- geprüft: fehlt korrekt auf der letzten Seite, kein falsches Matching auf
-- die "weitere Informationen zur Veranstaltung"-Ticketlinks trotz
-- ähnlichem Wortlaut).
update sources
set config = jsonb_set(config, '{nextPageSelector}', '"a[title=\"weiter zur nächsten Seite\"]"'::jsonb)
where id in (
  'b01be354-da6a-4fa4-b9a0-3ead63d762fa', -- Herkulessaal
  '54bfadaf-233a-4a9d-803e-a6332902ec0c'  -- Allerheiligen-Hofkirche
);
