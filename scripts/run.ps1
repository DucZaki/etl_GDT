# =============================================================================
# scripts/run.ps1  -  entry point invoked by Task Scheduler, Hop Server and
#                     drive_watch.py. Loads .env, then runs one or more pipelines.
# =============================================================================
param(
    [string]$Pipeline = "pipelines\01_check_drive.hpl",
    [switch]$All,
    [string]$LogLevel = $env:ETL_LOG_LEVEL
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

if (-not $LogLevel) { $LogLevel = "BASIC" }

# --- load .env (never committed) ------------------------------------------
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim())
        }
    }
}
$env:HOP_IMPORT_ENVIRONMENT_VARIABLES = "Y"

# --- resolve Hop home -------------------------------------------------------
$hopHome = if ($env:HOP_HOME) { $env:HOP_HOME } else { "C:\Users\minhd\apache-hop-2.20.0\hop" }
$hopRun  = Join-Path $hopHome "hop-run.bat"
if (-not (Test-Path $hopRun)) { throw "hop-run.bat not found at $hopRun" }

if (-not $env:HOP_CONFIG_FOLDER) { $env:HOP_CONFIG_FOLDER = "$env:USERPROFILE\.hop\config" }
if (-not $env:HOP_AUDIT_FOLDER)  { $env:HOP_AUDIT_FOLDER  = "$env:USERPROFILE\.hop\audit" }

$steps = if ($All) {
    @("pipelines\01_check_drive.hpl", "pipelines\02_drive_to_supabase.hpl")
} else {
    @($Pipeline)
}

foreach ($p in $steps) {
    if (-not (Test-Path $p)) { throw "Pipeline not found: $p" }
    Write-Host "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') :: $p ===" -ForegroundColor Cyan
    & $hopRun -j default -f (Resolve-Path $p) -r local -l $LogLevel
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $p (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}
Write-Host "=== ALL PIPELINES FINISHED OK ===" -ForegroundColor Green