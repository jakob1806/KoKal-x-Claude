# Klassik München — Premium-Konzert- & Veranstaltungsplattform

Die beste Plattform für klassische Musik, Chormusik, Oper, Vokalmusik, Kirchenmusik und Orchesterkonzerte in München — alle Veranstaltungen an einem Ort, automatisch aktuell gehalten.

## Stack (Kurzfassung)
Flutter (iOS/Android) · Supabase (Postgres + PostGIS) · Meilisearch · flutter_map/OpenStreetMap · Firebase Cloud Messaging · Supabase Edge Functions · GitHub Actions/Codemagic.
Begründung der Wahl: [docs/01-architecture.md](docs/01-architecture.md#1-zusammenfassung-der-stack-entscheidung)

## Projektstruktur
```
app/        Flutter-Client — Grundgerüst lauffähig (Home, Suche, Karte, Kalender, Profil, Event-Detail als Platzhalter)
admin/      Next.js-Admin-Dashboard — Grundgerüst lauffähig (Events-Liste live gegen Supabase)
backend/    Supabase-Migrationen (vollständiges Schema), Seed-Daten, Edge Functions (folgen Phase 1)
docs/       Vollständige Projektplanung
.github/    CI/CD-Workflows (Flutter, Admin-Dashboard, Supabase-Migrationen)
```

## Planungsdokumente
1. [Software-Architektur](docs/01-architecture.md)
2. [Datenbankschema](docs/02-database-schema.md)
3. [API-Konzept](docs/03-api-concept.md)
4. [Designsystem](docs/04-design-system.md)
5. [Navigationsstruktur](docs/05-navigation-structure.md)
6. UI-Wireframes — als interaktives Artefakt veröffentlicht (Link im Chat)
7. [MVP-Plan](docs/06-mvp-plan.md)
8. [Roadmap](docs/07-roadmap.md)

## Lokal starten

**Flutter-App**
```
cd app
cp .env.example .env   # mit echten Supabase-Keys füllen
flutter pub get
flutter run
```

**Admin-Dashboard**
```
cd admin
cp .env.local.example .env.local   # mit echten Supabase-Keys füllen
npm install
npm run dev
```

**Backend (Supabase, lokal via Docker)**
```
cd backend
supabase start   # benötigt Docker Desktop, siehe „Offene Punkte" unten
supabase db reset   # wendet alle Migrationen + Seed-Daten an
```

## Status — Phase 0 abgeschlossen, Backend live
- Vollständiges Postgres-Schema als 14 geordnete Migrationen (`backend/supabase/migrations`) inkl. RLS-Policies ist auf dem echten Supabase-Projekt angewendet, Seed-Daten für 6 Münchner Venues + 2 Beispiel-Events geladen
- Flutter-Grundgerüst: Theme/Design-Tokens, go_router mit Tab-Shell, alle 6 Kernscreens als Platzhalter, Karte läuft auf flutter_map/OpenStreetMap (kein API-Key/Billing nötig), `flutter analyze`/`flutter test` grün
- Admin-Dashboard-Grundgerüst: Next.js + Supabase-Client, Events-Liste live gegen echte Daten, Navigation für alle geplanten Redaktionsbereiche, `npm run build` grün
- CI/CD-Workflows für alle drei Teile eingerichtet
- Repo auf GitHub: [jakob1806/KoKal-x-Claude](https://github.com/jakob1806/KoKal-x-Claude)
- `app/.env` und `admin/.env.local` sind lokal mit echten Supabase-Zugangsdaten befüllt (nicht committet)

### Offene Punkte für Phase 1
- **Docker** ist auf dieser Maschine nicht installiert — ohne Docker lässt sich `supabase start` (lokale Dev-Datenbank) hier nicht ausführen; Migrationen werden direkt gegen das echte Projekt gepusht (`supabase db push`). Der CI-Workflow `supabase-migrations.yml` testet zusätzlich gegen eine frische lokale Instanz in GitHub Actions (dort ist Docker vorhanden).
- Restliche Beispiel-Events aus dem MVP-Plan folgen, sobald das Admin-Dashboard Schreibfunktionen hat (bewusst nicht als Fake-Daten vorab angelegt).
- Auth-Flow (Sign in with Apple/Google), Meilisearch-Anbindung: siehe Roadmap Phase 1.
