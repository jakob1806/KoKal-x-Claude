-- Erweiterungen, siehe docs/02-database-schema.md §2
create extension if not exists "uuid-ossp";   -- uuid_generate_v4()
create extension if not exists postgis;        -- Geodaten (Umkreissuche)
create extension if not exists pg_trgm;        -- Fuzzy-Matching für Dedupe & Suche
create extension if not exists vector;         -- Embeddings für Empfehlungen (Phase 3), Paketname "pgvector"
create extension if not exists pgmq;           -- Message Queue für Ingestion-Pipeline
