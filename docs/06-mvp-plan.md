# MVP-Plan

**Leitfrage für jede Entscheidung:** Löst dieses Feature das Kernversprechen — "alle klassischen Veranstaltungen Münchens an einem Ort, immer aktuell" — oder ist es Politur, die auch in v1.1 kommen kann?

## 1. MVP-Scope (v1.0)

### Enthalten
- **Home**: Heute in München, Beliebte Veranstaltungen, Kostenlose Konzerte, Dieses Wochenende, Neue Veranstaltungen (Empfehlungen-Sektion mit regelbasiertem statt ML-Algorithmus, siehe unten)
- **Suche**: Volltextsuche über Werk/Komponist/Ensemble/Venue mit Autocomplete (Meilisearch), Suchverlauf, Trending
- **Karte**: interaktive Karte mit Clustering, Filter, Vorschau-Sheet, externe Navigation (Apple/Google Maps Deeplink)
- **Kalender**: Monats-/Agenda-Ansicht, ICS-Export, Apple-/Google-Kalender-Sync
- **Favoriten**: speichern, eine Standardliste (eigene benannte Listen sind v1.1)
- **Event-Detail** vollständig: Programm, Mitwirkende, Ort, Preis, Barrierefreiheit, Parken, MVV (statisch verlinkt, Live-Abfahrten sind v1.1), Teilen, Ticketlink
- **Personenseiten & Ensembleseiten**: Komponisten, Dirigenten, Solisten, Chöre, Orchester — Biografie, kommende/vergangene Konzerte
- **Venue-Seiten**: die ~15–20 wichtigsten Münchner Spielstätten redaktionell vollständig gepflegt
- **Profil**: Interessen (Genres, Komponisten, Venues), Benachrichtigungseinstellungen, Dark/Light/System
- **Push-Benachrichtigungen**: neue passende Events, Preisänderung, fast ausverkauft, Erinnerung "morgen"
- **Filter**: Datum, Genre, Preis, Entfernung, Barrierefrei, Open Air
- **Admin-Dashboard (Basis)**: Events manuell anlegen/bearbeiten, Import-Runs einsehen, Duplikate-Review-Queue, Bilder verwalten
- **Ingestion-Pipeline (Basis)**: Schema.org/iCal/RSS-Connectoren für die 10–15 wichtigsten Quellen (Bayerische Staatsoper, Isarphilharmonie/Gasteig HP8, Prinzregententheater, Herkulessaal, Münchner Philharmoniker, große Kirchengemeinden), Change-Detection, tägliche Aktualisierung

### Bewusst verschoben (nicht in v1.0)
| Feature | Grund |
|---|---|
| KI-Funktionen ("Was soll ich heute Abend hören?", automatische Zusammenfassungen) | Braucht zuerst kritische Masse an Daten + Nutzungssignalen, um Mehrwert zu zeigen |
| ML-basierter Empfehlungsalgorithmus (Embeddings) | v1.0 nutzt regelbasierte Heuristik (siehe unten), reicht für ersten Nutzwert |
| Apple Watch App, Live Activities, Widgets | Erst wenn iPhone-App stabil & Kern-Nutzerbasis vorhanden |
| Apple Wallet Tickets | Abhängig davon, ob Veranstalter strukturierte Ticket-Daten liefern — Pilotphase mit 1–2 Partnern zuerst |
| PDF-Programmheft | Nice-to-have, kein Kernversprechen |
| Live-Auslastung, Live-MVV-Abfahrten | Brauchen zusätzliche externe API-Integrationen, nach Kernfunktionen priorisiert |
| Web-Scraping als Datenquelle | Nur strukturierte Quellen (Schema.org/iCal/RSS) in v1.0, Scraping erst wenn rechtlich/technisch je Quelle geprüft |
| Eigene benannte Favoriten-Listen | Eine Standardliste reicht initial |
| Mehrsprachigkeit (Englisch) | Deutsch zuerst, München-Fokus; Englisch in v1.1 für internationale Besucher/Touristen |

### MVP-Empfehlungslogik (regelbasiert, kein ML)
Einfache, transparente Regeln statt Blackbox — schnell zu bauen, sofort nützlich:
- Nutzer hat Genre X in Interessen → Boost für Events mit Genre X
- Nutzer hat Venue X favorisiert/besucht (via `event_views`) → Boost für weitere Events an Venue X
- Nutzer hat Komponist/Ensemble favorisiert → Boost für Events mit diesem Komponisten/Ensemble
- Fallback: Popularität (Anzahl Favorisierungen) + zeitliche Nähe (bald stattfindende Events zuerst)
- Kombiniert als gewichtete Score-Summe in einer SQL-Query/View — kein separater ML-Service nötig

---

## 2. Erfolgskriterien für MVP-Launch
- ≥ 300 aktuelle, geprüfte Veranstaltungen zum Launch (kritische Masse für "nie wieder andere Seiten durchsuchen")
- Automatisierte Ingestion deckt ≥ 70% der Events ab, Rest manuell über Admin-Dashboard
- Datenaktualität: kritische Änderungen (Absage, Ausverkauft, Preis) innerhalb von 24h erkannt
- App-Start bis interaktive Home-Ansicht < 2s (kalt), Suche antwortet < 200ms

## 3. Out-of-Scope-Klarstellung
Kein Ticketverkauf/-Zahlungsabwicklung in der App selbst — die App verlinkt immer zum Veranstalter/Ticketanbieter. Das vermeidet PCI-Compliance-Aufwand und Konflikte mit bestehenden Ticketing-Partnern der Venues, hält den Fokus auf Discovery & Aggregation.
