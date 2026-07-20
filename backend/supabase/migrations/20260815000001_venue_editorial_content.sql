-- Redaktioneller Ausbau der 7 bestehenden Venues: docs/06-mvp-plan.md
-- verlangt "die ~15-20 wichtigsten Münchner Spielstätten redaktionell
-- vollständig gepflegt" — description_de/accessibility/parking_info_de/
-- mvv_stops waren bei allen 7 komplett leer. Barrierefreiheit/Parken/MVV
-- recherchiert über die jeweiligen offiziellen Seiten (residenz-muenchen.de,
-- gasteig.de, staatsoper.de) und kultur-barrierefrei-muenchen.de am
-- 2026-07-20. mvv_stops bewusst OHNE walk_minutes, wo keine Quelle eine
-- konkrete Gehzeit nennt — lieber weglassen als schätzen.

update venues set
  description_de = 'Konzertsaal im Nordflügel der Münchner Residenz, Stammspielstätte des Symphonieorchesters des Bayerischen Rundfunks.',
  accessibility = '{"wheelchair": true, "hearing_loop": false, "sign_language": false}'::jsonb,
  parking_info_de = '6 Behindertenparkplätze im Apothekenhof (Zufahrt über Alfons-Goppel-Straße). Parken direkt am Odeonsplatz ist knapp — Parkhäuser Opern-Garage (Max-Joseph-Platz) und Salvatorgarage in der Nähe.',
  mvv_stops = '[{"name": "Odeonsplatz", "lines": ["U3", "U4", "U5", "U6"]}, {"name": "Marienplatz", "lines": ["S1-S8", "U3", "U6"]}]'::jsonb
where slug = 'herkulessaal';

update venues set
  description_de = 'Interims-Konzertsaal der Münchner Philharmoniker im Kulturzentrum Gasteig HP8 im Werksviertel-Süd, während der Sanierung des Gasteig-Hauptgebäudes am Rosenheimer Platz.',
  accessibility = '{"wheelchair": true, "hearing_loop": false, "sign_language": false}'::jsonb,
  parking_info_de = 'Keine eigenen Besucherparkplätze am HP8 — Parkplatz am ursprünglichen Gasteig-Standort (Blumengroßmarkt) mit kostenlosem Shuttle empfohlen. Vor Ort 14 gekennzeichnete Behindertenparkplätze.',
  mvv_stops = '[{"name": "Schäftlarnstraße/Gasteig HP8", "lines": ["Bus 54", "Bus 153", "Bus X30", "Bus X204"]}, {"name": "Brudermühlstraße", "lines": ["U2"]}, {"name": "Candidplatz", "lines": ["U1", "U2"]}]'::jsonb
where slug = 'isarphilharmonie';

update venues set
  description_de = 'Historisches Festspielhaus am Prinzregentenplatz, wiederaufgebaut und 1996 wiedereröffnet, heute u.a. Sitz der Bayerischen Theaterakademie August Everding.',
  accessibility = '{"wheelchair": true, "hearing_loop": false, "sign_language": false}'::jsonb,
  parking_info_de = 'Behindertenparkplätze in der Nigerstraße.',
  mvv_stops = '[{"name": "Prinzregentenplatz", "lines": ["U4", "Bus 100", "Bus 54"]}]'::jsonb
where slug = 'prinzregententheater';

update venues set
  description_de = 'Jesuitenkirche in der Fußgängerzone der Altstadt, Deutschlands erste Renaissance-Kirche. Hauptraum schwellenlos über Rampe zugänglich; die Fürstengruft im Untergeschoss ist nur über Treppen erreichbar, kein barrierefreies WC vorhanden.',
  accessibility = '{"wheelchair": true, "hearing_loop": false, "sign_language": false}'::jsonb,
  parking_info_de = 'Verkehrsberuhigte Lage, keine direkte Zufahrt — mehrere Parkhäuser in der näheren Umgebung, u.a. 8 Behindertenparkplätze.',
  mvv_stops = '[{"name": "Karlsplatz (Stachus)", "lines": ["S1-S8", "U4", "U5"]}, {"name": "Marienplatz", "lines": ["S1-S8", "U3", "U6"]}]'::jsonb
where slug = 'st-michael';

update venues set
  description_de = 'Ehemalige Hofkirche im Ostflügel der Münchner Residenz, nach Kriegszerstörung wiederaufgebaut und heute vor allem als Konzertsaal genutzt.',
  accessibility = '{"wheelchair": true, "hearing_loop": false, "sign_language": false}'::jsonb,
  parking_info_de = 'Die Residenz hat keine eigenen Besucherparkplätze — kostenpflichtige Tiefgarage am Nationaltheater (Max-Joseph-Platz). 4 Behindertenstellplätze in der Maximilianstraße gegenüber Hausnr. 2.',
  mvv_stops = '[{"name": "Odeonsplatz", "lines": ["U3", "U4", "U5", "U6"]}, {"name": "Marienplatz", "lines": ["S1-S8", "U3", "U6"]}, {"name": "Nationaltheater", "lines": ["Tram 19"]}]'::jsonb
where slug = 'allerheiligen-hofkirche';

update venues set
  description_de = 'Das Nationaltheater am Max-Joseph-Platz ist die Hauptspielstätte der Bayerischen Staatsoper und des Bayerischen Staatsballetts, eines der bedeutendsten Opernhäuser der Welt.',
  accessibility = '{"wheelchair": true, "hearing_loop": true, "sign_language": false}'::jsonb,
  parking_info_de = 'Behindertenparkplätze in der Maximilianstraße nahe dem barrierefreien Eingang (Seiteneingang zum Restaurant).',
  mvv_stops = '[{"name": "Marienplatz", "lines": ["S1-S8", "U3", "U6"]}, {"name": "Nationaltheater", "lines": ["Tram 19", "Tram 21"]}, {"name": "Rindermarkt", "lines": ["Bus 52", "Bus 62"]}]'::jsonb
where slug = 'bayerische-staatsoper';

update venues set
  accessibility = '{"wheelchair": true, "hearing_loop": false, "sign_language": false}'::jsonb,
  parking_info_de = 'Kein eigener Parkplatz — Parkmöglichkeiten in der Umgebung (Ettstraße, Maxburgstraße, Kapellenstraße), dort auch Behindertenparkplätze. Kein barrierefreies WC vor Ort.',
  mvv_stops = '[{"name": "Marienplatz", "lines": ["S1-S8", "U3", "U6", "Bus 52", "Bus 132"]}]'::jsonb
where slug = 'frauenkirche-muenchen';
