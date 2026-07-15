# API-Konzept

## 1. Grundprinzip
Drei API-Schichten, kein monolithisches Custom-Backend nötig:

1. **PostgREST (auto-generiert von Supabase)** — für alle einfachen CRUD-/Lese-Operationen direkt gegen Tabellen/Views, abgesichert über RLS.
2. **Meilisearch-Proxy** — eigene Edge Function für Suche/Autocomplete (verbirgt Meilisearch-Key, macht Rate-Limiting, loggt `search_history`).
3. **Edge Functions** — für alles, was Geschäftslogik, externe API-Calls oder privilegierte Operationen braucht (Empfehlungen, Wallet-Passes, PDF-Export, KI-Funktionen, Ingestion).

Alle Endpunkte laufen über `https://<project>.supabase.co/...`, Auth via `Authorization: Bearer <jwt>` (anonym oder eingeloggt).

---

## 2. PostgREST-Beispiele (automatisch, kein eigener Code nötig)

```
GET /rest/v1/events?status=eq.scheduled&start_datetime=gte.2026-07-15&select=*,venue:venues(*),event_genres(genre:genres(*))
GET /rest/v1/events?id=eq.<uuid>&select=*,venue:venues(*),event_works(work:works(*,composer:persons(*))),event_participants(person:persons(*),ensemble:ensembles(*))
GET /rest/v1/venues?slug=eq.isarphilharmonie&select=*,events(*)
GET /rest/v1/persons?slug=eq.johann-sebastian-bach&select=*,works(*)
POST /rest/v1/favorites   { "event_id": "..." }
DELETE /rest/v1/favorites?event_id=eq.<uuid>
PATCH /rest/v1/notification_preferences?user_id=eq.<uuid>  { "price_changes": false }
```

Postgres-Views kapseln komplexere Listen (`events_today`, `events_this_weekend`, `events_free`, `events_almost_sold_out`), damit der Client keine Business-Logik in Query-Parametern nachbilden muss.

Umkreissuche (PostGIS) über eine RPC-Funktion, da PostgREST keine nativen Geo-Operatoren als Query-Param kennt:

```sql
create function events_nearby(lat float, lng float, radius_km float)
returns setof events as $$
  select e.* from events e
  join venues v on v.id = e.venue_id
  where ST_DWithin(v.location, ST_MakePoint(lng, lat)::geography, radius_km * 1000)
  order by ST_Distance(v.location, ST_MakePoint(lng, lat)::geography);
$$ language sql stable;
```
Aufruf: `POST /rest/v1/rpc/events_nearby { "lat": 48.13, "lng": 11.58, "radius_km": 5 }`

---

## 3. Such-API (Edge Function `/search`)

```
GET /functions/v1/search?q=bach+matthäus&filters=genre:kirchenmusik&facets=genre,venue,date
```
Response:
```json
{
  "hits": [ { "id": "...", "title": "Matthäus-Passion", "venue": "Herkulessaal", "start_datetime": "2026-08-02T19:30:00+02:00", "thumbnail": "..." } ],
  "facetDistribution": { "genre": { "kirchenmusik": 4 }, "venue": { "Herkulessaal": 2 } },
  "estimatedTotalHits": 4
}
```
- Autocomplete: `GET /functions/v1/search/suggest?q=bac` → Top-5 Vorschläge über Werke, Komponisten, Ensembles, Venues gemischt, gerankt nach Meilisearch-Relevanz + Popularität
- Trending: `GET /functions/v1/search/trending` → aus `trending_searches` materialized view
- Jede erfolgreiche Suche eines eingeloggten Nutzers wird asynchron in `search_history` geloggt (fire-and-forget, blockiert nicht die Response)

**Meilisearch-Index-Struktur** (`events`-Index, synchronisiert per DB-Trigger → `pgmq`-Queue → Edge Function `sync-search-index`):
```json
{
  "id": "uuid",
  "title": "...", "subtitle": "...",
  "composers": ["Johann Sebastian Bach"],
  "works": ["Matthäus-Passion"],
  "ensembles": ["Bachchor München"],
  "conductors": ["..."], "soloists": ["..."],
  "venue": "Herkulessaal", "district": "Maxvorstadt",
  "genres": ["kirchenmusik"],
  "start_timestamp": 1785686400,
  "price_min": 15, "is_free": false,
  "status": "scheduled"
}
```
Filterable Attribute: `genres, venue, district, start_timestamp, price_min, is_free, status`. Sortable: `start_timestamp, price_min`.

---

## 4. Edge Functions (Business-Logik)

| Endpoint | Methode | Zweck |
|---|---|---|
| `/functions/v1/recommendations` | GET | Personalisierte Empfehlungen für eingeloggten Nutzer (siehe Empfehlungs-Dokument in Roadmap) |
| `/functions/v1/ai/ask` | POST | "Was soll ich heute Abend hören?" — nimmt Nutzerpräferenz/Kontext, ruft Claude API mit Event-Kontext (RAG über heutige Events) |
| `/functions/v1/ai/summarize-program` | POST | Fasst Programm/Werkbeschreibung automatisch zusammen |
| `/functions/v1/ai/explain-composer` | GET | Kurzerklärung zu Komponist/Werk on-demand (gecacht in `persons.biography_de` nach erster Generierung) |
| `/functions/v1/wallet-pass` | POST | Generiert Apple-Wallet-`.pkpass` für ein Ticket/Event |
| `/functions/v1/program-pdf` | POST | Generiert PDF-Programmheft für ein Event |
| `/functions/v1/ics-export` | GET | ICS-Datei für Event oder gesamte Favoritenliste |
| `/functions/v1/mvv-departures` | GET | Live-Abfahrten nahe einer Venue (Proxy zu MVV-API, gecacht 60s) |
| `/functions/v1/weather` | GET | Wetter am Veranstaltungsort/-tag (Proxy zu DWD/OpenWeather, gecacht) |
| `/functions/v1/notify/*` | intern | Von `pg_cron`/DB-Triggern aufgerufen, verschickt FCM-Push bei Preisänderung, fast ausverkauft, neue Events etc. |
| `/functions/v1/ingest/*` | intern (Cron) | Pro Connector-Typ (Schema.org, iCal, RSS, Scraper) |
| `/functions/v1/admin/*` | diverse | Duplikatserkennung, Import-Trigger, Bild-Upload-Verarbeitung — nur `admin`/`editor`-Rolle |

---

## 5. Realtime
Supabase Realtime (Postgres-Replication) auf:
- `events` (Filter auf `id in (favorisierte Event-IDs)`) → Live-Update im Client bei Preisänderung/Absage ohne Reload
- `duplicate_candidates` im Admin-Dashboard → Live-Queue für Redakteure

---

## 6. Rate Limiting & Abuse-Schutz
- Supabase Edge Functions: eingebautes Rate-Limiting pro IP/JWT (via Upstash Redis in der Function, 60 req/min für `/search`, 10 req/min für `/ai/*`)
- PostgREST: Supabase-seitiges Connection-Pooling + statement timeout (5s) gegen teure Queries
- Ingestion-Endpunkte: nur via Service-Role-Key aus Cron, nicht öffentlich erreichbar

---

## 7. Versionierung
- PostgREST-Views sind der stabile Vertrag zum Client — Schema-Änderungen an Basistabellen brechen die App nicht, solange Views kompatibel bleiben
- Edge Functions unter `/functions/v1/...`, Breaking Changes → `/v2/...` parallel betreiben, App-seitig per Remote-Config (Supabase-Tabelle `app_config`) umschaltbar
