-- Review von 20260814000002 (Excel-Import) ergab: diese drei neu
-- angelegten Zeilen sind Duplikate bereits bestehender Einträge und werden
-- hier wieder entfernt, statt die bereits angewendete Migration nachträglich
-- zu verändern.
--  * 'Münchener Bach-Chor' (Ensemble) -- Schreibweisen-Duplikat von 'Bachchor München'.
--  * 'Dom zu Unserer Lieben Frau' (Venue) -- dasselbe Gebäude wie 'Frauenkirche
--    (Dom zu Unserer Lieben Frau)'.
--  * 'Bayerische Staatsoper' (Organizer) -- ist bei uns eine Venue, kein
--    separater Organizer-Datensatz.
delete from ensembles where slug = 'muenchener-bach-chor';
delete from venues where slug = 'dom-zu-unserer-lieben-frau';
delete from organizers where slug = 'bayerische-staatsoper';
