# =============================================================================
# scripts/install-schedule.ps1  -  registers a Windows Task Scheduler job that
# runs the whole ETL every ETL_SCHEDULE_MINUTES minutes (default 15).
# Run once, as the user that owns the .hop config / Google Drive token.
# =============================================================================
param([int]$Minutes = [int]($env:ETL_SCHEDULE_MINUTES))

if (-not $Minutes) { $Minutes = 15 }
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$run  = Join-Path $root "scripts\run.ps1"

$action   = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$run`" -All"
$trigger  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $Minutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName "HopETL_DriveToSupabase" -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Scheduled task 'HopETL_DriveToSupabase' created: every $Minutes min -> $run"