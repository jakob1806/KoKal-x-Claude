# Klassik München — Premium-Konzert- & Veranstaltungsplattform

Die beste Plattform für klassische Musik, Chormusik, Oper, Vokalmusik, Kirchenmusik und Orchesterkonzerte in München — alle Veranstaltungen an einem Ort, automatisch aktuell gehalten.

## Stack (Kurzfassung)
Flutter (iOS/Android) · Supabase (Postgres + PostGIS) · Meilisearch · Google Maps · Firebase Cloud Messaging · Supabase Edge Functions · GitHub Actions/Codemagic.
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
cp .env.example .env   # mit echten Supabase-/Google-Maps-Keys füllen
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

## Status — Phase 0 abgeschlossen
- Vollständiges Postgres-Schema als 14 geordnete Migrationen (`backend/supabase/migrations`) inkl. RLS-Policies und Seed-Daten für 6 Münchner Venues
- Flutter-Grundgerüst: Theme/Design-Tokens, go_router mit Tab-Shell, alle 6 Kernscreens als Platzhalter, `flutter analyze`/`flutter test` grün
- Admin-Dashboard-Grundgerüst: Next.js + Supabase-Client, Events-Liste live angebunden, Navigation für alle geplanten Redaktionsbereiche, `npm run build` grün
- CI/CD-Workflows für alle drei Teile eingerichtet

### Offene Punkte für Phase 1
- **Supabase-Cloud-Projekt** (dev/staging/prod) ist noch nicht angelegt — das erfordert einen Supabase-Account, den nur du einrichten kannst. Sobald ein Projekt existiert, verbinde ich das lokale Repo per `supabase link`.
- **Docker** ist auf dieser Maschine nicht installiert — ohne Docker lässt sich `supabase start` (lokale Dev-Datenbank) hier nicht ausführen. Die Migrationen wurden daher bisher nur manuell gegen das Schema-Dokument geprüft, noch nicht live gegen Postgres getestet. Der CI-Workflow `supabase-migrations.yml` führt diesen Test automatisch in GitHub Actions aus (dort ist Docker vorhanden).
- Restliche 45 Beispiel-Events aus dem MVP-Plan folgen, sobald das Admin-Dashboard Schreibfunktionen hat (bewusst nicht als Fake-Daten vorab angelegt).
- Auth-Flow (Sign in with Apple/Google), Meilisearch-Anbindung, Google-Maps-Integration: siehe Roadmap Phase 1.
