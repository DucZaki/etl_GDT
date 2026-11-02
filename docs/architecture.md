# Architecture

## Flow
Google Drive (etl/sample_data_dirty.xlsx)
  -> Apache Hop Excel input (3 branches, one per sheet)
  -> staging tables stg_customers / stg_products / stg_orders (all text)
  -> SQL validation + cleaning (dedupe, normalize, FK checks, flags)
  -> prod tables customers / products / orders (upsert by PK)
  -> Supabase PostgREST (CRUD) + RLS

## Components
- Hop pipelines 01_check_drive, 02_drive_to_supabase
- Hop run config `local` (engine local)
- Supabase Postgres (session pooler 5432, sslmode=require)
- Google Drive VFS + OAuth refresh token (Hop Google plugin)
- Windows Task Scheduler / Hop Server REST / Drive Changes API watcher

## Idempotency
- Staging: truncate + load per batch.
- Prod: upsert by PK; `batch_id` (uuid) carried in etl_run_log.

## Secrets
- Never in git. `.env` (gitignored) -> env vars -> Hop `${VAR}` via HOP_IMPORT_ENVIRONMENT_VARIABLES=Y.
- Google OAuth token lives outside the project (`~/.hop/gdrive/tokens`).