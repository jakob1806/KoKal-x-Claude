-- Live-Testlauf (siehe PR #32) zeigte: ein Kategorie-Filter auf "Musik"/
-- "Klassik" ist für gasteig.de zu grob — Hip-Hop-Workshops, Tanzabende und
-- generische "Musik"-Events dort tragen dieselben Tags, und alle 9
-- gefundenen Events lagen in Sälen (Halle E, Gasteig Motorama), die nicht
-- als venues existieren. Filter jetzt gezielt auf den Saal-Tag
-- "Isarphilharmonie" statt auf die Inhalts-Kategorie — präziser für diese
-- Quelle, da die Isarphilharmonie der tatsächliche Klassik-Konzertsaal im
-- Gasteig-Komplex ist.
update sources
set config = jsonb_set(config, '{includeIfTagContains}', '["isarphilharmonie"]'::jsonb)
where id = '196d8940-bd6c-4350-9d60-cc09a02a4033';
