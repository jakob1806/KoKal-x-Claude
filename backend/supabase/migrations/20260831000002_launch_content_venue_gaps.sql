-- Redaktionelle Vervollständigung (Roadmap Phase 3, "Launch-Content"): die
-- drei aktiven, aber bisher unvollständigen Venues (haben Events, aber
-- weder mvv_stops noch parking_info_de) — recherchiert über die
-- offiziellen Anfahrtsseiten der jeweiligen Institution (siehe Quellen
-- unten), Format wie bei den bereits gepflegten Venues (Prinzregenten-
-- theater, Isarphilharmonie).

-- Quelle: muffatwerk.de/de/besucherservice/wegbeschreibung
update venues set
  mvv_stops = '[
    {"name": "Rosenheimer Platz", "lines": ["S-Bahn (alle Linien)", "Tram 15", "Tram 25"]},
    {"name": "Isartor", "lines": ["S-Bahn (alle Linien)"]},
    {"name": "Deutsches Museum / Am Gasteig", "lines": ["Tram 16"]}
  ]'::jsonb,
  parking_info_de = 'Keine eigenen Besucherparkplätze am Muffatwerk (nur Be-/Entladen) — Parkgarage des Gasteig über die Rosenheimer Straße empfohlen. 19 kostenlose Behindertenparkplätze in der Gasteiggarage, 10 weitere am Müller''schen Volksbad.'
where name = 'Muffathalle';

-- Quelle: muenchen.travel/pois/stadt-viertel/herz-jesu-kirche (MVG-Angaben);
-- keine belastbare Quelle für venueeigene Parkplätze gefunden — parking_info_de
-- bleibt bewusst leer statt geraten.
update venues set
  mvv_stops = '[
    {"name": "Rotkreuzplatz", "lines": ["U1", "U7", "Bus 53", "Bus 62", "Bus 63", "Bus 144"]},
    {"name": "Romanplatz", "lines": ["Tram 12", "Tram 16", "Tram 17", "Bus 51", "Bus 151"]},
    {"name": "Neuhausen", "lines": ["Tram 12"]}
  ]'::jsonb
where name = 'Herz-Jesu-Kirche';

-- Quelle: staatsoper.de/en/visit, muenchen.de/verkehr/tiefgarage-vor-der-oper
update venues set
  mvv_stops = '[
    {"name": "Nationaltheater", "lines": ["Tram 19", "Tram 21"]},
    {"name": "Odeonsplatz", "lines": ["U3", "U4", "U5", "U6", "Bus 100", "Bus 153"]},
    {"name": "Marienplatz", "lines": ["S-Bahn (alle Linien)", "U3", "U6"]}
  ]'::jsonb,
  parking_info_de = 'Parkhaus an der Oper (Max-Joseph-Platz), täglich 6:00-1:00 Uhr geöffnet (Ausfahrt rund um die Uhr möglich), Nachttarif-Pauschale bis 8:00 Uhr.'
where name = 'Nationaltheater München';
