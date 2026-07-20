-- Die Excel-Stammdaten-Quelle (20260814000002) hatte keine Sterbedaten-
-- Spalte, nur ein Geburtsjahr — death_date blieb bei ALLEN 25 importierten
-- Personen NULL, auch bei den längst verstorbenen. Trägt hier die
-- öffentlich bekannten Sterbedaten der neun bereits verstorbenen
-- Personen aus diesem Import nach (alle anderen 16 sind noch aktiv).
update persons set death_date = '1982-03-29' where slug = 'carl-orff';
update persons set death_date = '2004-07-13' where slug = 'carlos-kleiber';
update persons set death_date = '2021-10-18' where slug = 'edita-gruberova';
update persons set death_date = '1987-03-26' where slug = 'eugen-jochum';
update persons set death_date = '1890-01-20' where slug = 'franz-lachner';
update persons set death_date = '2019-12-01' where slug = 'mariss-jansons';
update persons set death_date = '1949-09-08' where slug = 'richard-strauss';
update persons set death_date = '1996-08-14' where slug = 'sergiu-celibidache';
update persons set death_date = '2013-02-22' where slug = 'wolfgang-sawallisch';
