# Roadmap

## Phase 0 — Fundament (Wochen 1–3)
- Projekt-Setup: Repo-Struktur, CI/CD-Pipelines, Supabase-Projekte (dev/staging/prod), Flutter-App-Grundgerüst mit Design-Tokens
- Datenbankschema produktiv aufsetzen (siehe `02-database-schema.md`), RLS-Policies
- Admin-Dashboard-Grundgerüst (Next.js), manuelle Event-Pflege funktionsfähig
- Erste 5 Venues + 50 Events **manuell** angelegt (Qualitätsreferenz für spätere Ingestion)

## Phase 1 — MVP-Kernfunktionen (Wochen 4–10)
- Home, Suche (inkl. Meilisearch-Integration), Karte, Kalender, Event-Detail, Profil, Favoriten
- Personen-/Ensemble-/Venue-Seiten
- Push-Benachrichtigungen (FCM-Grundintegration: neue Events, Preisänderung, Erinnerung)
- Regelbasierte Empfehlungen auf Home
- Auth (anonym + Sign in with Apple/Google)
→ **Meilenstein: interner Alpha-Test (TestFlight/Play Internal)**

## Phase 2 — Datenaktualität automatisieren (Wochen 8–14, parallel zu Phase 1)
- Ingestion-Pipeline: Schema.org-Parser, iCal-Adapter, RSS-Adapter
- Connectoren für die 10–15 wichtigsten Quellen live schalten
- Change-Detection + Diff-Engine, kritische Änderungen triggern Push
- Fuzzy-Matching/Dedupe-Engine + Admin-Review-Queue
→ **Meilenstein: ≥ 70% der Events automatisch aktuell gehalten**

## Phase 3 — Öffentlicher Launch (Woche 15–16)
- App-Store- & Play-Store-Freigabe
- Barrierefreiheits-Audit (VoiceOver/TalkBack-Durchlauf, Kontrast-Check)
- Performance-Härtung (Caching-Layer, CDN vor Storage, Lasttests auf Ingestion)
- Launch-Content: alle wichtigen Münchner Venues redaktionell vollständig
→ **Meilenstein: Öffentlicher Store-Launch**

## Phase 4 — Vertiefung & Bindung (Monate 4–6 nach Launch)
- Eigene benannte Favoriten-Listen
- Live-MVV-Abfahrten, Live-Wetter am Event-Tag
- Apple Wallet Tickets (Pilot mit 1–2 Veranstaltern mit strukturierten Ticket-Daten)
- PDF-Programmheft-Export
- Web-Scraping-Connectoren für Quellen ohne strukturierte Daten (nach rechtlicher Einzelprüfung)
- Englische Lokalisierung (internationale Besucher/Touristen)
- Erste iteration Analytics-getriebene Empfehlungsverbesserung (A/B-Test der Scoring-Gewichte)

## Phase 5 — KI-Funktionen (Monate 6–9)
- "Was soll ich heute Abend hören?" — konversationelle Empfehlung (RAG über aktuelle Events)
- Automatische Programm-Zusammenfassungen, Komponisten-Kurzerklärungen (gecacht nach erster Generierung)
- Ähnliche-Konzerte-Empfehlung auf Event-Detail (zunächst regelbasiert aus Phase 1, hier verfeinert)

## Phase 6 — ML-Empfehlungen & Erweiterte Plattform (Monate 9–12)
- Embedding-basierte Empfehlungen (`pgvector`), Ablösung/Ergänzung der regelbasierten Logik
- Widgets (iOS Home-Screen, Android)
- Live Activities (laufendes/bevorstehendes Konzert)
- Apple Watch App (Favoriten, heutige Events, Erinnerungen)
- Live-Auslastungsanzeige (in Kooperation mit Venues, sofern Daten verfügbar)

## Phase 7 — Skalierung über München hinaus (ab Monat 12, offen)
- Architektur ist bereits stadt-agnostisch (Venue/Event-Modell hat keine München-spezifischen Constraints) — Expansion auf weitere Städte als strategische Option, kein technischer Umbau nötig, nur Content-/Ingestion-Aufbau pro neuer Stadt

---

## Kontinuierlich (über alle Phasen)
- Wöchentliche Datenqualitäts-Review (Duplikate, veraltete Events, fehlende Bilder)
- Nutzer-Feedback-Loop (In-App-Feedback → Admin-Dashboard "Fehlerberichte")
- Accessibility- & Performance-Regressionstests in CI
