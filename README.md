# Klassik München — Premium-Konzert- & Veranstaltungsplattform

Die beste Plattform für klassische Musik, Chormusik, Oper, Vokalmusik, Kirchenmusik und Orchesterkonzerte in München — alle Veranstaltungen an einem Ort, automatisch aktuell gehalten.

## Stack (Kurzfassung)
Flutter (iOS 13+/Android) · Supabase (Postgres + PostGIS + pg_trgm-Suche) · flutter_map/OpenStreetMap · Firebase Cloud Messaging · Supabase Edge Functions · GitHub Actions/Codemagic.
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

## Status
**Backend (live auf dem echten Supabase-Projekt):** vollständiges Postgres-Schema, RLS-Policies, Auth-Bootstrap (erster Nutzer wird automatisch Admin), Venue-Geodaten-RPCs, `search_all`-Volltextsuche (pg_trgm), Seed-Daten für 6 Münchner Venues.

**Admin-Dashboard:** E-Mail-Code-Login mit Rollen-Gate (`proxy.ts`), vollständiges CRUD für Venues/Events/Personen/Ensembles inkl. Programm- & Mitwirkenden-Editor pro Event. `npm run lint`/`build` grün.

**Flutter-App:** Theme/Design-Tokens, go_router mit Tab-Shell, Karte auf flutter_map/OpenStreetMap (kein API-Key/Billing), E-Mail-Code-Login im Profil-Tab, Such-Tab live gegen `search_all` verdrahtet (inkl. echter Suchhistorie für eingeloggte Nutzer), Detailseiten für Events/Personen/Ensembles/Venues, Push-Grundintegration (FCM: Berechtigung, Token-Speicherung in `push_tokens`, Vordergrund-Handling). `flutter analyze`/`test` grün, iOS-Simulator-Build lokal verifiziert.

CI/CD-Workflows für alle drei Teile eingerichtet. Repo auf GitHub: [jakob1806/KoKal-x-Claude](https://github.com/jakob1806/KoKal-x-Claude). `app/.env` und `admin/.env.local` sind lokal mit echten Supabase-Zugangsdaten befüllt (nicht committet).

**Firebase-Projekt:** `klassik-muenchen`, Android + iOS registriert (`flutterfire configure`). iOS-Minimum dafür von 12.0 auf **13.0** angehoben (von Firebase SDK 11.x vorausgesetzt) — in der Praxis kein relevanter Nutzerverlust, iOS 12 ist von 2018.

### Offene Punkte
- **Docker** ist auf dieser Maschine nicht installiert — Migrationen gehen direkt gegen das echte Projekt (`supabase db push`); der CI-Workflow `supabase-migrations.yml` testet zusätzlich gegen eine frische lokale Instanz in GitHub Actions.
- **Push-Benachrichtigungen**: Client-seitig fertig (Token-Registrierung funktioniert). Serverseitiges Auslösen (neue Events, Preisänderungen, Erinnerungen → tatsächlicher Versand über FCM) ist noch offen, braucht eine Edge Function mit Firebase-Admin-Credentials als Supabase-Secret.
- **iOS-Zustellung** von Push braucht zusätzlich einen APNs-Auth-Key im Firebase-Projekt — das wiederum braucht ein Apple-Developer-Programm-Konto (kostenpflichtig). Android/FCM funktioniert unabhängig davon bereits vollständig.
- **Sign in with Apple/Google** sind im Code verdrahtet, brauchen aber OAuth-Zugangsdaten im Supabase-Dashboard (Authentication → Providers) — der E-Mail-Code-Login funktioniert schon vollständig ohne das.
- Meilisearch bleibt eine spätere Option für bessere Facetten-UX/Skalierung — die aktuelle Postgres-Suche reicht für MVP-Datenvolumen.
- **Hinweis für lokale Builds:** Liegt das Repo in einem iCloud-Drive-synchronisierten Ordner (z. B. `~/Desktop`), kann `flutter build ios` beim Codesigning mit „resource fork … not allowed" fehlschlagen. Kein Code-Problem — iCloud hängt Extended Attributes an; hilft: `xattr -cr build/ios/**/*.framework` vor dem Signieren, oder Projekt außerhalb eines iCloud-Ordners halten.
