# Designsystem

**Leitidee:** Ruhig, hochwertig, editoriell — näher an Apple Music/Apple TV als an einem klassischen Ticket-Portal. Große Bilder und Typografie tragen die Emotion, UI-Chrome tritt zurück.

## 1. Farbsystem

### Light Mode
| Token | Wert | Verwendung |
|---|---|---|
| `background.primary` | `#FAFAF8` | App-Hintergrund (leicht warmes Off-White, nicht klinisches Weiß) |
| `background.secondary` | `#FFFFFF` | Karten, Sheets |
| `background.elevated` | `#FFFFFF` + Shadow `0 8px 24px rgba(0,0,0,0.06)` | Modale, Popover |
| `text.primary` | `#1C1C1E` | Haupttext |
| `text.secondary` | `#6E6E73` | Metadaten, Untertitel |
| `text.tertiary` | `#A1A1A6` | Platzhalter, deaktiviert |
| `accent.primary` | `#8B2635` (gedecktes Bordeaux/Burgunder) | CTAs, aktive Zustände — Anspielung auf Konzertsaal-Samt, ohne kitschig zu sein |
| `accent.secondary` | `#C9A961` (gedämpftes Gold) | Highlights, "Empfehlung"-Badges, Premium-Akzente |
| `separator` | `#E5E5EA` | Trennlinien |
| `success` | `#34A853` | frei verfügbar |
| `warning` | `#E8A33D` | fast ausverkauft |
| `error` | `#D33B3B` | ausverkauft/abgesagt |

### Dark Mode
| Token | Wert |
|---|---|
| `background.primary` | `#0C0C0E` |
| `background.secondary` | `#1A1A1D` |
| `background.elevated` | `#232326` |
| `text.primary` | `#F5F5F7` |
| `text.secondary` | `#98989D` |
| `text.tertiary` | `#636366` |
| `accent.primary` | `#C4566B` (aufgehellt für Kontrast) |
| `accent.secondary` | `#D9BC7F` |
| `separator` | `#38383A` |

Alle Farbpaare erfüllen WCAG AA (Kontrast ≥ 4.5:1 für Fließtext, ≥ 3:1 für große Typografie).

### Glassmorphism — dezent, gezielt eingesetzt
Nur für: Tab-Bar-Hintergrund, Such-Overlay, Bottom-Sheets im halb-offenen Zustand.
```
background: rgba(250,250,248,0.72)   /* Light */
background: rgba(12,12,14,0.72)      /* Dark */
backdrop-filter: blur(24px) saturate(1.6)
border-top: 0.5px solid separator
```
Kein Glass-Effekt auf Karten, Buttons oder Listen — dort volle Deckkraft, damit große Eventbilder nicht optisch konkurrieren.

---

## 2. Typografie

- **Font:** SF Pro (iOS-nativ) / Roboto-Fallback Android, App-weit **Inter** als plattformübergreifende Konstante für Konsistenz zwischen iOS/Android (sehr nah an SF Pro, exzellente Lesbarkeit)
- Deutsche Sonderzeichen (Umlaute, ß) vollständig unterstützt

| Style | Größe/Zeilenhöhe | Gewicht | Verwendung |
|---|---|---|---|
| Display | 34/40 | Bold (700) | Hero-Titel Home |
| Title 1 | 28/34 | Bold | Event-Detail-Titel |
| Title 2 | 22/28 | Semibold (600) | Sektionstitel ("Heute in München") |
| Title 3 | 18/24 | Semibold | Karten-Titel |
| Body | 16/22 | Regular (400) | Fließtext |
| Callout | 15/20 | Regular | Sekundärtext, Beschreibungen |
| Footnote | 13/18 | Regular | Metadaten (Ort, Zeit auf Karten) |
| Caption | 11/13 | Medium (500) | Badges, Labels |

---

## 3. Spacing & Layout

8pt-Grid: `4, 8, 12, 16, 24, 32, 48, 64`
- Screen-Padding horizontal: `16` (Mobile), `24` (Tablet)
- Kartenabstand in Listen: `16`
- Sektionsabstand vertikal: `32`
- Viel Weißraum bewusst: Karten atmen, keine Content-Dichte wie bei klassischen Ticket-Portalen

**Radius:** Karten `20px`, Buttons `14px`, Bottom-Sheets `28px` (oben), Bilder in Karten `16px`

---

## 4. Komponenten (Kern-Set)

- **EventCard** — großes 16:9 oder 4:5-Bild, Titel, Venue+Zeit als Footnote, optionales Badge ("Fast ausverkauft", "Kostenlos", "Neu")
- **HeroCard** — Vollbild-Karte für Home-Hero, Titel over Gradient-Overlay (`linear-gradient(transparent, rgba(0,0,0,0.7))`)
- **FilterChip** — Pill-Form, aktiv = `accent.primary` gefüllt, inaktiv = Outline
- **BottomSheet** — für Filter, Event-Vorschau von der Karte, Teilen-Menü — Glass-Header, solider Content-Bereich
- **SegmentedControl** — für Kalender-Ansicht (Monat/Woche/Agenda)
- **PersonAvatar** — rund, für Dirigenten/Solisten in Mitwirkenden-Liste
- **MapMarker** — Custom-Pin mit Genre-Icon, Cluster-Bubble mit Zahl
- **PrimaryButton / SecondaryButton / IconButton**
- **Skeleton-Loader** statt Spinner für Listen/Karten (wahrgenommene Performance)

---

## 5. Bewegung & Animation

Prinzipien wie bei Apple: **physikalisch, nie linear, immer unterbrechbar.**
- Standard-Kurve: `Curves.easeOutCubic`, Dauer `250–350ms` für UI-Übergänge
- **Hero-Transition**: Event-Bild fliegt von der Karte in die Detailansicht (`Hero`-Widget), 400ms, `Curves.fastOutSlowIn`
- **Scroll**: native Bounce/Overscroll-Physik (`BouncingScrollPhysics` auf iOS-Feeling für beide Plattformen)
- **Listen-Eintritt**: leichtes Fade+Slide (8px) gestaffelt um 30ms pro Item, nur beim ersten Laden
- **Pull-to-Refresh**: custom, dezent, kein Standard-Spinner — kleine Note/Notensymbol-Animation als Marken-Detail
- Kein Overuse: Animation dient Orientierung (wo kam ich her, wo gehe ich hin), nie Selbstzweck

---

## 6. Bildsprache
- Großformatige, editoriell wirkende Konzertfotografie, keine Stock-Ticket-Optik
- Konsistentes Overlay-Gradient für Textlesbarkeit auf Bildern
- Platzhalter bei fehlendem Bild: generatives, genre-spezifisches abstraktes Artwork (kein graues Icon-Placeholder) — z. B. dezente Wellenform/Notenlinien-Muster in Genre-Akzentfarbe

---

## 7. Barrierefreiheit
- Alle interaktiven Elemente ≥ 44×44pt Touch-Target
- Dynamic Type / Textskalierung bis 200% unterstützt, Layout bricht nicht
- VoiceOver/TalkBack: semantische Labels auf allen Karten ("Matthäus-Passion, Bachchor München, heute 19:30 Uhr, Herkulessaal, ab 25 Euro")
- Kontrastmodus: `accent.primary` hat einen High-Contrast-Ersatzwert für Nutzer mit aktivierter "Erhöhter Kontrast"-Systemeinstellung
- Reduce-Motion-Setting wird respektiert (Hero-Transitions → einfacher Fade statt Flug-Animation)
- Genre-/Status-Badges nie nur farbcodiert, immer zusätzlich mit Text/Icon
