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
  -> Init staging schema       (Hop SQL action: sql/init/01_staging.sql)
  -> Load staging from Drive   (pipeline: read xlsx -> stg_customers/products/orders)
  -> Validate and upsert to DB (Hop Shell action: cleaning/clean.py)
  -> Success
```

Run it:

```bash
# macOS / Linux (Drive -> Supabase)
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-workflow.sh

# local xlsx (no Google Drive), for testing
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-workflow.sh --local
```

Open it in the GUI:

```bash
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/open-gui.sh workflows/etl_drive_to_db.hwf
```

The validation/cleaning step runs `cleaning/clean.py` via a Hop Shell action.
Staging keeps the raw rows; validation runs immediately after, before the upsert into
`customers` / `products` / `orders`.

### What happens, step by step

1. **Start** (`workflows/etl_drive_to_db.hwf`) — has `Repeat` enabled, Daily 02:00 (in-Hop schedule).
2. **Init staging schema** — runs `sql/init/01_staging.sql` on Supabase, so the three
   `stg_*` tables exist (idempotent, safe to re-run).
3. **Init logging schema** — runs `sql/init/03_logging.sql`, creating `etl_run_log` and
   `etl_rejects` if missing.
4. **Load staging from Drive** — pipeline `pipelines/drive/02_drive_to_supabase.hpl` reads
   the 3 sheets of the xlsx from Google Drive and inserts every raw row into
   `stg_customers`, `stg_products`, `stg_orders` (all text, no cleaning yet).
5. **Validate and upsert** — Hop Shell action calls `cleaning/clean.py`:
   - reads the `stg_*` tables into pandas;
   - dedupes, trims/normalizes names, emails, phones, cities, countries, dates;
   - checks FKs (`customer_id`, `product_id`), quantity, future dates, price mismatch;
   - upserts into `customers` / `products` / `orders` by primary key;
   - refreshes the `v_orders_clean` and `v_data_quality` views.
6. **Apply security** — runs `sql/init/06_security.sql` (RLS, policies, indexes, FKs).
7. **Log success** — appends one row to `etl_run_log` with row counts.
8. **Success** — workflow ends; if `Repeat` is on, `hop-run` stays alive until the next 02:00.

Any step failure jumps to **Log failure** (writes a `failed` row to `etl_run_log`) and then
**Abort**. The API reads only the **clean** tables, so consumers never see staging rows.

## Quick start
```powershell
cd C:\Users\minhd\Documents\Hop\default
copy .env.example .env   # fill in Supabase + Drive values
.\bin\windows\run.ps1 -Pipeline pipelines\drive\01_check_drive.hpl
```

## Read API

Flask API over the clean Supabase tables, for other systems to fetch data.

```bash
# start in background
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-api.sh --daemon

# stop
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/stop-api.sh
```

Base URL: `http://127.0.0.1:8000` (change `API_HOST` / `API_PORT` in `.env`).
Swagger-style index: `GET /`.

| Method | Path | Description |
|---|---|---|
| GET | `/health` | API + DB health |
| GET | `/api/v1/summary` | customer/product/order counts, revenue, latest ETL run |
| GET | `/api/v1/customers` | list (`limit`, `offset`, `q`, `status`, `country`) |
| GET | `/api/v1/customers/<id>` | one customer + latest 100 orders |
| GET | `/api/v1/products` | list (`limit`, `offset`, `q`, `category`, `currency`) |
| GET | `/api/v1/products/<id>` | one product + latest 100 orders |
| GET | `/api/v1/orders` | list (`limit`, `offset`, `customer_id`, `product_id`, `status`, `from`, `to`) |
| GET | `/api/v1/orders/<id>` | one order + customer + product |
| GET | `/api/v1/order-details` | joined orders + customers + products |
| GET | `/api/v1/etl/runs` | ETL run history |

Pagination: `limit` default 50, max 200; response `{"data": [...], "meta": {...}}`.
If `API_KEY` is set in `.env`, send header `X-API-Key`.

Postman: import `api/etl_gdt.postman_collection.json`, then set the `apiKey`
collection variable to the value in `.env`.

Details: `api/README.md`.

## Docs
- `docs/architecture.md` - flow and components
- `docs/mapping.md` - source -> staging -> prod mapping and rules
- `docs/runbook.md` - run, schedule, trigger, monitor, rollback

## Logs

- CLI (`run-workflow.sh`): `logs/run_YYYYMMDD_HHMMSS.log`
- GUI (press Run): `logs/executions/<uuid>/workflow-log.txt` (or `pipeline-log.txt`)
- API (`run-api.sh --daemon`): `logs/api_YYYYMMDD_HHMMSS.log`, PID in `logs/api.pid`
- Newest log path: `/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/last-log.sh`
- Copy newest to `logs/last-run.log`: `/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/last-log.sh --copy`

## Status
- Drive -> Supabase flow runs end-to-end: 43 customers / 27 products / 73 orders read;
  39 / 25 / 70 rows upserted after cleaning.
- Google OAuth app is in Testing mode, so the refresh token expires about every 7 days
  and needs re-authentication.
- `etl_run_log` is written by the workflow on every successful run.
- `etl_rejects` exists but row-level rejects are not yet wired into the workflow.
- Supabase connection metadata uses `${SUPABASE_*}` placeholders; real values come from `.env`.