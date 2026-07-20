-- photo_url für alle 7 Venues — bisher komplett leer. Direkte externe
-- Bild-URLs statt Supabase-Storage-Upload, gleiches Muster wie bereits bei
-- events.image_urls (siehe ingest-source/parsers/schema_org.ts/scrape.ts):
-- kein eigenes Hosting/Rechtemanagement nötig, Quelle bleibt verantwortlich.
--
-- residenz-muenchen.de/gasteig.de/st-michael-muenchen.de: bereits als
-- Scrape-Quellen erfolgreich per einfachem GET erreichbar (kein Bot-Schutz,
-- siehe robots.txt-Prüfungen in den jeweiligen sources-Migrationen) — Bild
-- direkt von dort verlinkt.
--
-- Bayerische Staatsoper: staatsoper.de sitzt hinter Cloudflare (siehe
-- 20260814000001_frauenkirche_scrape_source.sql-Kommentar) — ein dort
-- gehostetes Bild würde beim Laden in der App vermutlich genauso blockiert
-- wie der direkte Fetch. Prinzregententheater hat keine eigene, klar
-- lizenzierte Bildquelle gefunden. Für beide stattdessen ein Wikimedia-
-- Commons-Bild (Originaldatei, keine Bot-Sperre, klar lizenziert) —
-- gleiches Vorgehen auch für Frauenkirche, deren Bistums-Feed (siehe
-- Frauenkirche-Migration) selbst keine Bilder liefert.
update venues set photo_url = 'https://www.residenz-muenchen.de/bilder/raeume/herkulessaalDE001008-575.jpg' where slug = 'herkulessaal';
update venues set photo_url = 'https://www.gasteig.de/imgs/Filmfoniker_Iphil_21_11_c_Filmfoniker_25-scaled.jpg' where slug = 'isarphilharmonie';
update venues set photo_url = 'https://www.st-michael-muenchen.de/fileadmin/_processed_/8/7/csm_Kirchenschiff_aus_Mitteloeffnung.jpg_f9ea9015d7.jpg' where slug = 'st-michael';
update venues set photo_url = 'https://www.residenz-muenchen.de/bilder/ahkirche/allerheiligen-hofkirche_Scherf-Freudling790.jpg' where slug = 'allerheiligen-hofkirche';
update venues set photo_url = 'https://upload.wikimedia.org/wikipedia/commons/e/ed/Muenchen_Prinzregententheater-1.JPG' where slug = 'prinzregententheater';
update venues set photo_url = 'https://upload.wikimedia.org/wikipedia/commons/5/54/2019-01-26_Bayerische_Nationaltheater_03.jpg' where slug = 'bayerische-staatsoper';
update venues set photo_url = 'https://upload.wikimedia.org/wikipedia/commons/2/26/Frauenkirche_Munich_-_View_from_Peterskirche_Tower.jpg' where slug = 'frauenkirche-muenchen';
