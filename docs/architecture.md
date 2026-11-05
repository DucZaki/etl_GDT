# Architecture

## Flow
Google Drive (etl/sample_data_dirty.xlsx)
  -> Apache Hop Excel input (3 branches, one per sheet)
  -> staging tables stg_customers / stg_products / stg_orders (all text)
  -> Python cleaning (scripts/clean.py: dedupe, normalize, FK checks, flags)
  -> prod tables customers / products / orders (upsert by PK)
  -> Supabase PostgREST (CRUD) + RLS

## One-shot workflow
`workflows/etl_drive_to_db.hwf` is the single entry point:

1. `SQL` action -> `sql/01_staging.sql` (create staging tables + helper functions)
2. `PIPELINE` action -> `pipelines/02_drive_to_supabase.hpl` (read + staging)
3. `SQL` action -> `sql/02_clean.sql` (validate + clean + upsert)
4. `SUCCESS` action

`workflows/etl_local_to_db.hwf` is the same flow against `data/sample_data_dirty.xlsx`
(no Google Drive), useful for development.

## Components
- Hop workflow `etl_drive_to_db` / `etl_local_to_db`
- Hop pipelines 01_check_drive, 02_drive_to_supabase
- Hop run config `local` (engine local)
- Supabase Postgres (session pooler 5432, sslmode=require)
- Google Drive VFS + OAuth refresh token (Hop Google plugin)
- Windows Task Scheduler / Hop Server REST / Drive Changes API watcher

## Idempotency
- Staging: truncate + load per batch.
- Prod: upsert by PK; re-running the workflow is safe.
- `etl_run_log` is written by the workflow on every successful run (sql/04_log_run.sql).
- `etl_rejects` schema exists (`sql/03_logging.sql`) but row-level rejects are not yet wired.

## Secrets
- Never in git. `.env` (gitignored) -> env vars -> Hop `${VAR}` via `-s` (CLI) or `-D` (GUI).
- `metadata/rdbms/supabase.json` stores `${SUPABASE_*}` placeholders, never real values.
- Google OAuth token lives outside the project (`~/.hop/gdrive/tokens`).