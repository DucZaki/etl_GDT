# Runbook

## Run manually
```powershell
cd C:\Users\minhd\Documents\Hop\default
.\scripts\run.ps1 -All -LogLevel DEBUG
```

## Run one pipeline
```powershell
.\scripts\run.ps1 -Pipeline pipelines\02_drive_to_supabase.hpl
```

## Test Google Drive connectivity only
```powershell
.\scripts\run.ps1 -Pipeline pipelines\01_check_drive.hpl
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
.\scripts\trigger.ps1 -Name "pipelines\01_check_drive.hpl"
```

## File watch (Drive changes)
```powershell
python scripts\drive_watch.py --once   # test once
python scripts\drive_watch.py           # daemon, polls every 5 min
```

## Database
1. Supabase SQL Editor: run `sql/01_staging.sql`, then `sql/02_clean.sql`, then `sql/03_logging.sql`.
2. Run pipeline `02_drive_to_supabase.hpl`.
3. Check quality: `select * from v_data_quality;`

## Rollback
- Staging: pipeline truncates on every run, so re-running restores it.
- Prod: upsert by PK; to reset, `truncate customers, products, orders cascade;` then re-run.

## Monitoring
- `etl_run_log`: one row per pipeline run (status, rows, error).
- `etl_rejects`: rejected rows with reason.
- File log: `%HOP_AUDIT_FOLDER%\hopui.log`.