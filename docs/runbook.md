# Runbook

## Setup Google Drive (once per machine)
```bash
./scripts/setup-gdrive.sh   # points Hop VFS at the working OAuth client
```

## One-shot workflow (macOS / Linux)
```bash
./scripts/run-workflow.sh              # Google Drive -> staging -> validate -> DB
./scripts/run-workflow.sh --local      # local xlsx -> staging -> validate -> DB
```

## Schedule (macOS, every 15 min)
```bash
./scripts/install-schedule-macos.sh              # install (ETL_SCHEDULE_MINUTES=30 to change)
./scripts/install-schedule-macos.sh --uninstall  # remove
```
The job runs `/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-workflow.sh` and logs to `logs/run_YYYYMMDD_HHMMSS.log`.

Flow: `Start -> Init staging (SQL) -> Init logging (SQL) -> Load staging (pipeline) -> Validate and upsert (Python) -> Apply security (SQL) -> Log success (SQL) -> Success`.
No manual SQL editor is needed. On failure, a failed row is written to `etl_run_log` and the workflow aborts.

## Run manually (Windows)
```powershell
cd C:\Users\minhd\Documents\Hop\default
.\scripts\run.ps1 -All -LogLevel DEBUG
```
`run.ps1` only runs pipelines. For the full flow including init/validate/upsert,
open `workflows\etl_drive_to_db.hwf` in the Hop GUI and run it.

## Run one pipeline
```powershell
.\scripts\run.ps1 -Pipeline pipelines\drive\02_drive_to_supabase.hpl
```

## Test Google Drive connectivity only
```powershell
.\scripts\run.ps1 -Pipeline pipelines\drive\01_check_drive.hpl
```
Expected: `Read customers I=43`, `Read products I=27`, `Read orders I=73`.

## Schedule (every 15 min)
```powershell
.\scripts\install-schedule.ps1
# remove:
Unregister-ScheduledTask -TaskName HopETL_DriveToSupabase -Confirm:$false
```

## REST trigger (Hop Server)
```powershell
.\scripts\start-hop-server.ps1   # terminal 1
.\scripts\trigger.ps1 -Name "pipelines\drive\01_check_drive.hpl"
```

## File watch (Drive changes)
```powershell
python scripts\drive_watch.py --once   # test once
python scripts\drive_watch.py           # daemon, polls every 5 min
```

## Database
1. Fresh database only: run `sql/init/01_staging.sql` once (staging tables).
2. Run the workflow: `./scripts/run-workflow.sh`. The Hop SQL action creates the
   target tables/views from `sql/steps/02_clean.sql` and upserts the data.
3. Optional: run `sql/init/03_logging.sql` once to create the run/reject tables.
4. Check quality: `select * from v_data_quality;`

## Rollback
- Staging: pipeline truncates on every run, so re-running restores it.
- Prod: upsert by PK; to reset, `truncate customers, products, orders cascade;` then re-run.

## Monitoring
- `etl_run_log`: one row per pipeline run (status, rows, error).
- `etl_rejects`: rejected rows with reason.
- CLI file log: `logs/run_YYYYMMDD_HHMMSS.log`.
- GUI execution log: `logs/executions/<uuid>/workflow-log.txt` (or `pipeline-log.txt`) — after the metadata change.
- Hop GUI console log: `%HOP_AUDIT_FOLDER%\hopui.log` (fallback).
- API log: `logs/api_YYYYMMDD_HHMMSS.log` (PID in `logs/api.pid`).

## Read API (Flask)

Start:
```bash
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-api.sh --daemon
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-api.sh          # foreground
```

Stop:
```bash
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/stop-api.sh
```

Health + smoke test:
```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/v1/summary
curl "http://127.0.0.1:8000/api/v1/order-details?limit=5"
```

Config (`.env`):
```env
API_HOST=127.0.0.1
API_PORT=8000
# API_KEY=secret    # optional; clients then send X-API-Key
```

Endpoints and filters: `api/README.md`.
