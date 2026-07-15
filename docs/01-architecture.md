# Architektur — Klassik-München-Plattform

## 1. Zusammenfassung der Stack-Entscheidung

| Bereich | Wahl | Alternative erwogen | Begründung |
|---|---|---|---|
| Client | **Flutter** (iOS, Android, später Web) | React Native | Ein Codebase für beide Stores, exzellente Animationsperformance (60/120fps), native-nahes Look&Feel via Cupertino-Widgets für das gewünschte Apple-Gefühl |
| Backend/DB | **Supabase** (managed Postgres) | Firebase/Firestore | Die Domäne ist hochgradig relational (Event ↔ Werke ↔ Komponisten ↔ Mitwirkende ↔ Venues ↔ Veranstalter, n:m überall). Firestore zwingt zu Denormalisierung und macht komplexe Filter (Genre + Datum + Umkreis + Preis) und Joins schwer. Postgres + **PostGIS** löst Geo-Umkreissuche und Relationen sauber. Row Level Security ersetzt Firebase-Security-Rules 1:1. |
| Volltextsuche | **Meilisearch** (self-hosted, EU-Server) | Algolia | Gleichwertige Autocomplete/Typo-Toleranz-Qualität, deutlich günstiger im Betrieb, self-hosted (DSGVO, EU-Datenresidenz einfacher), hervorragende Unterstützung für Facetten (Genre, Ort, Datum) und deutsche Sprache/Umlaute |
| Karten | **Google Maps SDK** im App-Kern, **Apple Maps** als externer Navigations-Deeplink auf iOS | Nur Apple Maps | Google Maps hat auf Android/iOS gleichermaßen ausgereiftes Clustering & Places-Daten; Nutzer bekommen trotzdem die Wahl, extern in Apple Maps oder Google Maps zu navigieren |
| Push | **Firebase Cloud Messaging (FCM)** | Supabase Realtime only | FCM bleibt der De-facto-Standard für zuverlässige iOS/Android-Push auch außerhalb eines Firebase-Backends; Supabase Edge Functions triggern FCM serverseitig |
| Auth | **Supabase Auth** (E-Mail, Apple Sign-In, Google Sign-In) | Firebase Auth | Konsistent mit dem Rest des Backends, RLS-Integration nativ |
| Business-Logik | **Supabase Edge Functions** (Deno/TypeScript) | Cloud Functions | Gleiches Prinzip wie Firebase Functions, aber näher an der Postgres-Instanz (geringere Latenz), TypeScript |
| Bilder/Storage | **Supabase Storage** + CDN-Caching (Cloudflare) | Firebase Storage | Ein Anbieter weniger, direkte Policy-Kopplung an DB-Rechte |
| CI/CD | **GitHub Actions** + **Codemagic** (Flutter-natives CI, macOS-Runner für iOS-Signing) | Fastlane manuell | Codemagic ist auf Flutter spezialisiert, übernimmt Code-Signing, TestFlight/Play-Console-Uploads |
| Error-Tracking | **Sentry** (Flutter SDK) | Firebase Crashlytics | Bessere plattformübergreifende Traces, Performance-Monitoring inklusive |
| Analytics | **PostHog** (self-hosted-fähig) | Firebase Analytics | DSGVO-freundlicher, Feature-Flags & Funnels inklusive, gut für Empfehlungsalgorithmus-Auswertung |

**Kernprinzip:** Ein Backend (Supabase/Postgres) als "Source of Truth", Meilisearch als abgeleiteter, eventuell-konsistenter Suchindex (asynchron synchronisiert via DB-Trigger → Edge Function → Meilisearch-Update).

---

## 2. High-Level-Architektur

```
                        ┌─────────────────────────────────────────┐
                        │              Flutter App                 │
                        │   iOS · Android · (später Web via Flutter)│
                        │   Riverpod (State) · go_router (Nav)      │
                        └───────────────┬───────────────────────────┘
                                        │ HTTPS / REST / Realtime WS
                        ┌───────────────▼───────────────────────────┐
                        │            Supabase Edge (API Gateway)     │
                        │  • PostgREST (Auto-REST über Postgres)     │
                        │  • Supabase Auth                           │
                        │  • Supabase Realtime (Preisänderungen etc.)│
                        │  • Edge Functions (Deno/TS, Business-Logik)│
                        └───────┬─────────────────────┬──────────────┘
                                │                       │
                 ┌──────────────▼───────────┐   ┌───────▼────────────┐
                 │   PostgreSQL + PostGIS    │   │    Meilisearch      │
                 │   (Source of Truth)       │   │  (Suchindex, EU)    │
                 │   RLS pro Tabelle         │   │  Sync via Trigger/  │
                 │                            │   │  Queue (pg_cron +   │
                 │                            │   │  Edge Function)     │
                 └──────────────┬────────────┘   └─────────────────────┘
                                │
                 ┌──────────────▼─────────────────────────────────────┐
                 │              Ingestion-Pipeline (separat)            │
                 │  Cron-gesteuerte Supabase Edge Functions /           │
                 │  kleiner Node/Deno-Worker-Service (Fly.io/Railway)   │
                 │  • Schema.org/Event-Parser                            │
                 │  • iCal/RSS-Adapter                                   │
                 │  • Venue-spezifische Connectoren                      │
                 │  • Diff-Engine (Change Detection)                     │
                 │  • Admin-Review-Queue für unsichere Matches            │
                 └───────────────────────────────────────────────────┘
                                │
                 ┌──────────────▼────────────┐
                 │   Admin-Dashboard (Web)    │
                 │   Next.js + Supabase Auth  │
                 │   (Redakteure, Import-Mgmt)│
                 └────────────────────────────┘

  Externe Dienste: FCM (Push) · Sentry (Errors) · PostHog (Analytics)
  · Cloudflare (CDN vor Storage) · MVV-API (Abfahrten) · Wetter-API (DWD/OpenWeather)
```

---

## 3. Client-Architektur (Flutter)

**Struktur (Feature-first, Clean-Architecture-light):**

```
app/
  lib/
    core/
      network/            # Dio-Client, Interceptors, Error-Mapping
      config/              # Env, Flavors (dev/staging/prod)
      theme/               # Design-Tokens, Light/Dark ThemeData
      router/              # go_router Config, Deep-Links
      widgets/             # Shared UI-Kit (Buttons, Cards, Sheets)
      utils/
    features/
      home/
        data/              # Repositories, DTOs
        domain/            # Entities, UseCases
        presentation/      # Screens, Controller (Riverpod), Widgets
      search/
      map/
      calendar/
      favorites/
      event_detail/
      profile/
      persons/             # Komponisten/Dirigenten/Chöre/Orchester/Solisten
      venues/
      onboarding/
      notifications/
    l10n/                  # de.arb, en.arb
    main.dart
  test/
```

- **State Management:** Riverpod (testbar, kompilierzeitsicher, gut für async Datenquellen + Caching)
- **Navigation:** `go_router` mit Deep-Link-Support (`muc-classical://event/{id}`, Universal Links für Web-Fallback)
- **Netzwerk:** `dio` + Retrofit-ähnliche Code-Generierung (`retrofit.dart`) gegen Supabase PostgREST/Edge Functions
- **Offline/Caching:** `drift` (SQLite) als lokaler Cache für Favoriten & zuletzt gesehene Events (Offline-Fähigkeit), `cached_network_image` für Bilder
- **Animationen:** implizite Animationen + `flutter_animate` für Apple-artige Übergänge, Hero-Animationen zwischen Karten und Detailseite

---

## 4. Backend-Architektur im Detail

### 4.1 API-Zugriff
- **Lesen (Events, Venues, Personen):** direkt über PostgREST-Autoserver von Supabase (`GET /rest/v1/events?...`), abgesichert über RLS (public read für veröffentlichte Events)
- **Suche/Autocomplete:** eigener leichter Edge-Function-Proxy `/search` vor Meilisearch (verbirgt API-Key, erlaubt Rate-Limiting, loggt Trending-Searches)
- **Schreiben (Favoriten, Profil, Listen):** PostgREST mit RLS `auth.uid() = user_id`
- **Komplexe Business-Logik** (Empfehlungsalgorithmus, Wallet-Pass-Generierung, PDF-Programmheft, KI-Zusammenfassungen): Edge Functions

### 4.2 Ingestion-Pipeline (Herzstück der Datenaktualität)
Eigenständiger, von der Kern-App entkoppelter Layer, siehe Detailkonzept in Abschnitt 6.

### 4.3 Caching-Strategie
- **CDN (Cloudflare)** vor Supabase Storage für Bilder (Edge-Caching, Bildvarianten via Cloudflare Images/Resizing)
- **HTTP-Caching**: `Cache-Control` Header auf PostgREST-Views für selten wechselnde Daten (Venues, Personen: 1h), Events-Liste kurzlebiger (5 min) da Restkarten-Status sich ändert
- **Client-seitig**: Riverpod `AsyncValue`-Caching + `drift`-Persistenz für Favoriten/Offline
- **Meilisearch** selbst ist bereits ein In-Memory-Index → Suchanfragen sind Cache-frei schnell (<50ms)

### 4.4 Skalierung
- Supabase Compute vertikal skalierbar (Start: kleine Instanz, München-Markt ist überschaubar an Datenvolumen: geschätzt 500–3000 aktive Events gleichzeitig)
- Meilisearch als separater Kubernetes/Fly.io-Container, horizontal hinter Load Balancer bei Bedarf
- Ingestion-Worker sind zustandslos, horizontal skalierbar (mehrere Connectoren parallel, Queue via `pg_cron` + `pgmq` Message Queue in Postgres)
- Read-Replicas bei Bedarf (Supabase unterstützt Read-Replicas ab bestimmtem Tier)

### 4.5 Deployment
- **Backend:** Supabase-Projekte pro Umgebung (dev / staging / prod), Migrationsverwaltung via `supabase/migrations` + Supabase CLI, automatisiert über GitHub Actions bei Merge auf `main`
- **Edge Functions:** `supabase functions deploy` im CI
- **App:** Codemagic-Pipelines pro Flavor → TestFlight (iOS) / Play Console Internal Testing (Android) bei jedem Merge auf `develop`, manuelle Promotion zu Store-Release
- **Admin-Dashboard:** Vercel-Deployment (Next.js), separates Repo oder Monorepo-Package

---

## 5. Authentifizierung
- Supabase Auth: E-Mail/Passwort optional, primär **Sign in with Apple** & **Google Sign-In** (niedrige Einstiegshürde, App-Store-Pflicht bei Apple sowieso wenn andere Social-Logins angeboten werden)
- Anonyme Nutzung möglich (Supabase Anonymous Auth) — App ist auch ohne Account voll nutzbar (Discovery, Suche, Karte); Account nur nötig für Favoriten-Sync, Benachrichtigungen, Empfehlungen
- Admin-Dashboard: separate Rollen (`admin`, `editor`) via Postgres-Row `user_roles`, geprüft in RLS-Policies

---

## 6. Datenaktualitäts-Architektur (Kurzfassung, Details in eigenem Dokument möglich)
Mehrstufiger Ingestion-Ansatz — siehe `docs/02-database-schema.md` (Tabellen `sources`, `ingestion_runs`) und Roadmap-Phase 2:

1. **Strukturierte Quellen zuerst**: Schema.org/Event JSON-LD von Veranstalter-Websites, iCal-Feeds, RSS — regelmäßig gecrawlt (stündlich–täglich, konfigurierbar pro Quelle)
2. **Change-Detection**: Hash-Vergleich pro Event-Datensatz, bei Abweichung → Diff wird erzeugt, kritische Felder (Preis, Absage, Ausverkauft, Zeit/Ort) triggern sofortige Realtime-Benachrichtigung an betroffene Nutzer (Favoriten)
3. **Konfidenz-basiertes Matching**: Neue Rohdaten werden gegen bestehende Personen/Venues/Ensembles gefuzzy-matcht (`pg_trgm`); niedrige Konfidenz → Admin-Review-Queue statt Auto-Publish
4. **Scraping nur als letzte Instanz**: nur für Quellen ohne strukturierte Daten, mit expliziter Robots.txt-Prüfung und Rate-Limiting, rechtliche Prüfung pro Quelle dokumentiert in `sources.legal_basis`
5. **Manuelle Pflege**: Admin-Dashboard immer als Override-Ebene verfügbar

---

## 7. Sicherheit & Datenschutz
- RLS auf jeder Tabelle, Default-Deny
- Personenbezogene Daten (Profil, Standort) minimal gehalten, Standort nur mit Opt-in für "in der Nähe"
- DSGVO: EU-Hosting (Supabase Frankfurt-Region), Meilisearch EU-Server, klare Auftragsverarbeitungsverträge
- Secrets ausschließlich in Supabase Vault / GitHub Actions Secrets, nie im Client

---

## 8. Offene Architekturentscheidungen für spätere Phasen
- Web-Version der App (Flutter Web vs. separates Next.js-Frontend) — Entscheidung in Phase 3
- Empfehlungsalgorithmus: Start regelbasiert (siehe Roadmap), spätere ML-Pipeline (z.B. via Postgres `pgvector` für Embedding-basierte Ähnlichkeit) ist bereits im Schema vorbereitet
