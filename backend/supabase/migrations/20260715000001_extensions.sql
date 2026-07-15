-- Erweiterungen, siehe docs/02-database-schema.md §2
-- UUIDs nutzen das in Postgres eingebaute gen_random_uuid() (kein Extension nötig;
-- uuid-ossp liegt auf Supabase-Projekten im "extensions"-Schema und wäre sonst
-- unqualifiziert nicht auffindbar). postgis/pg_trgm/vector/pgmq werden hier ohne
-- WITH SCHEMA erzeugt und landen dadurch im "public"-Schema, wo der Rest der
-- Migrationen sie unqualifiziert referenziert.
create extension if not exists postgis;        -- Geodaten (Umkreissuche)
create extension if not exists pg_trgm;        -- Fuzzy-Matching für Dedupe & Suche
create extension if not exists vector;         -- Embeddings für Empfehlungen (Phase 3), Paketname "pgvector"
create extension if not exists pgmq;           -- Message Queue für Ingestion-Pipeline
