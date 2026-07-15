# Navigationsstruktur

## 1. Tab-Bar (Root-Navigation)

```
┌────────┬────────┬────────┬────────┬────────┐
│  Home  │ Suche  │ Karte  │Kalender│ Profil │
└────────┴────────┴────────┴────────┴────────┘
```
Favoriten ist bewusst **kein** eigener Tab, sondern über Profil + einen Schnellzugriff-Button auf Home erreichbar (5-Tab-Limit für Klarheit; Favoriten sind kein täglicher Einstiegspunkt für alle Nutzer).

## 2. Screen-Baum

```
Root (Tab-Navigator)
├── Home
│   ├── HeroSection (rotierend: Top-Empfehlung des Tages)
│   ├── "Heute in München" → HorizontalList → EventDetail
│   ├── "Beliebte Veranstaltungen" → HorizontalList
│   ├── "Empfehlungen für dich" → HorizontalList
│   ├── "Demnächst ausverkauft" → HorizontalList
│   ├── "Kostenlose Konzerte" → HorizontalList
│   ├── "Heute Abend" / "Dieses Wochenende" → HorizontalList
│   ├── "Neue Veranstaltungen" → HorizontalList
│   └── → EventDetail (Deep-Link-Ziel: /event/:slug)
│
├── Suche
│   ├── SearchInput (Autocomplete-Dropdown)
│   ├── EmptyState: Suchverlauf + Trending Searches
│   ├── SearchResults (gruppiert: Events, Werke, Komponisten, Ensembles, Venues)
│   ├── FilterSheet (Modal, von überall aufrufbar)
│   └── → EventDetail | PersonDetail | EnsembleDetail | VenueDetail
│
├── Karte
│   ├── MapView (Cluster-Marker)
│   ├── FilterBar (oben, horizontal scrollbar Chips)
│   ├── BottomSheet-Preview bei Marker-Tap (Bild, Titel, Ort, Zeit, Preis)
│   └── → EventDetail (via "Details anzeigen" im Preview-Sheet)
│
├── Kalender
│   ├── SegmentedControl: Monat | Woche | Agenda
│   ├── MonthView / WeekView / AgendaList
│   ├── Sync-Optionen (Sheet): Apple Kalender, Google Kalender, ICS-Export
│   └── → EventDetail
│
├── Profil
│   ├── Account-Header (Avatar, Name, Login-Prompt falls anonym)
│   ├── "Meine Favoriten" → FavoritesList → EventDetail
│   ├── "Meine Listen" → ListOverview → ListDetail
│   ├── Interessen → InterestsEditor (Komponisten, Orte, Chöre, Orchester)
│   ├── Benachrichtigungseinstellungen → NotificationSettings
│   ├── Darstellung (Dark/Light/System)
│   ├── Einstellungen (Sprache, Standort-Berechtigung, Datenschutz)
│   └── Support/Feedback
│
├── EventDetail (/event/:slug) — kein Tab, überall erreichbar
│   ├── Bildergalerie (Hero, swipebar)
│   ├── Titel, Untertitel, Genre-Badges, Status-Badge
│   ├── Programm (Werke, Komponisten, Pausen-Markierung)
│   ├── Mitwirkende (Dirigent, Solisten, Ensemble → PersonDetail/EnsembleDetail)
│   ├── Ort-Karte (Mini-Map) → VenueDetail
│   ├── Praktische Infos (Dauer, Barrierefreiheit, Parken, MVV, Wetter)
│   ├── Preis + Ticket-CTA (extern)
│   ├── Actions: Favorisieren, Teilen, Kalender hinzufügen, Wallet-Pass
│   └── "Ähnliche Veranstaltungen"
│
├── PersonDetail (/person/:slug) — Komponist | Dirigent | Solist
│   ├── Foto, Biografie, Geburts-/Sterbedaten, Nationalität
│   ├── Kommende Veranstaltungen
│   ├── Vergangene Veranstaltungen
│   └── Externe Links (Wikipedia, Website, Social)
│
├── EnsembleDetail (/ensemble/:slug) — Chor | Orchester | Ensemble
│   └── analog PersonDetail + Mitgliederzahl, Gründungsjahr, Heimat-Venue
│
├── VenueDetail (/venue/:slug)
│   ├── Fotos, Beschreibung, Adresse, Kapazität
│   ├── Karte + Anfahrt (Apple/Google Maps Deep-Link)
│   ├── Parkmöglichkeiten, MVV-Anbindung (Live-Abfahrten)
│   ├── Barrierefreiheit
│   └── Kommende Veranstaltungen an diesem Ort
│
└── Onboarding (nur beim ersten Start)
    ├── Willkommen
    ├── Interessen wählen (Genres, Komponisten optional)
    ├── Standort-Berechtigung anfragen
    ├── Benachrichtigungen anfragen
    └── → Home
```

## 3. Deep-Link-Schema

```
muc-classical://event/{slug}
muc-classical://person/{slug}
muc-classical://ensemble/{slug}
muc-classical://venue/{slug}
muc-classical://search?q={query}
https://app.muc-classical.de/...          (Universal Links, gleiche Struktur, Web-Fallback)
```
Verwendung: Push-Notifications, Teilen-Funktion, Widgets, Live Activities, Apple-Watch-App verlinken direkt auf diese Routen.

## 4. Modale/Sheets (überlagern Tab-Navigation, kein eigener Tab-Wechsel)
- Filter-Sheet (Suche & Karte)
- Event-Vorschau-Sheet (Karte)
- Teilen-Sheet
- Kalender-Sync-Sheet
- Login/Signup-Sheet (bei geschützten Aktionen im anonymen Modus)
- Bild-Vollbildansicht (Galerie-Zoom)

## 5. Navigations-Prinzipien
- Zurück-Geste (Swipe-from-edge iOS, Android-Back) funktioniert überall konsistent
- Tab-Wechsel behält Scroll-Position pro Tab (kein Reset)
- Tief verlinkte Detailseiten zeigen trotzdem sinnvolle Zurück-Navigation (zum Tab, von dem aus zugegriffen wurde, oder zu Home als Fallback bei Direktlink/Push)
