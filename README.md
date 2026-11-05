# etl_GDT

ETL pipeline: **Google Drive (xlsx) -> Apache Hop -> Supabase Postgres**.

- Source: `googledrive:///etl/sample_data_dirty.xlsx` (3 sheets: customers, products, orders)
- Ingest: Apache Hop 2.19+ (Excel input, one branch per sheet)
- Target: Supabase Postgres (session pooler, port 5432, SSL)
- Cleaning: dedupe, normalize, FK checks, quality flags, upsert by PK

## One-shot flow (everything inside Apache Hop)

`workflows/etl_drive_to_db.hwf`:

```
Start
  -> Init staging schema       (Hop SQL action: sql/01_staging.sql)
  -> Load staging from Drive   (pipeline: read xlsx -> stg_customers/products/orders)
  -> Validate and upsert to DB (Hop Shell action: scripts/clean.py)
  -> Success
```

Run it:

```bash
# macOS / Linux (Drive -> Supabase)
./scripts/run-workflow.sh

# local xlsx (no Google Drive), for testing
./scripts/run-workflow.sh --local
```

Open it in the GUI:

```bash
./scripts/open-gui.sh workflows/etl_drive_to_db.hwf
```

The validation/cleaning step is a Hop SQL action, so no manual SQL editor is needed.
Staging keeps the raw rows; validation runs immediately after, before the upsert into
`customers` / `products` / `orders`.

## Quick start
```powershell
cd C:\Users\minhd\Documents\Hop\default
copy .env.example .env   # fill in Supabase + Drive values
.\scripts\run.ps1 -Pipeline pipelines\01_check_drive.hpl
```

## Docs
- `docs/architecture.md` - flow and components
- `docs/mapping.md` - source -> staging -> prod mapping and rules
- `docs/runbook.md` - run, schedule, trigger, monitor, rollback

## Status
- Drive -> Supabase flow runs end-to-end: 43 customers / 27 products / 73 orders read;
  39 / 25 / 70 rows upserted after cleaning.
- Google OAuth app is in Testing mode, so the refresh token expires about every 7 days
  and needs re-authentication.
- `etl_run_log` is written by the workflow on every successful run.
- `etl_rejects` exists but row-level rejects are not yet wired into the workflow.
- Supabase connection metadata uses `${SUPABASE_*}` placeholders; real values come from `.env`.