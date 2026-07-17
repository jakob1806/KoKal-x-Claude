-- BayernCloud Tourismus (data.bayerncloud.digital) liefert pro Event ein
-- Pflicht-Attributionsfeld: "Wir weisen Sie darauf hin, dass der
-- entsprechende Urheberrechtsvermerk der Datensätze mit angegeben werden
-- muss" (Nutzungsbedingungen Teil C §18 dataCycle) — die API selbst liefert
-- dafür copyrightNotice (z.B. "CC BY 4.0 Bayern Tourismus Marketing GmbH")
-- und sdLicense (Lizenz-URL) direkt auf jedem Event-Objekt.
--
-- Generisch statt BayernCloud-spezifisch benannt (attribution_* statt
-- bayerncloud_*), da jede künftige Quelle mit vergleichbarer
-- Lizenzauflage (z.B. eine andere Landesdatenbank) dasselbe Feld
-- mitnutzen kann, statt pro Quelle eigene Spalten zu brauchen. NULL für
-- alle bisherigen Quellen (Scraping/Schema.org ohne explizite
-- Lizenzangabe) — kein rückwirkender Bedarf.
alter table events
  add column attribution_notice text,
  add column attribution_license_url text;

comment on column events.attribution_notice is
  'Pflicht-Urheberrechtsvermerk von Quellen mit expliziter Lizenzauflage (z.B. BayernCloud Tourismus) — muss in der App angezeigt werden, wenn gesetzt.';
comment on column events.attribution_license_url is
  'Lizenz-URL passend zu attribution_notice (z.B. CC-BY-4.0-Link).';
