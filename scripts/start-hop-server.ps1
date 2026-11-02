# =============================================================================
# scripts/start-hop-server.ps1  -  starts Hop Server (REST API on :8080).
# =============================================================================
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim())
        }
    }
}
$env:HOP_IMPORT_ENVIRONMENT_VARIABLES = "Y"

$hopHome = if ($env:HOP_HOME) { $env:HOP_HOME } else { "C:\Users\minhd\apache-hop-2.20.0\hop" }
$server  = Join-Path $hopHome "hop-server.bat"
if (-not (Test-Path $server)) { throw "hop-server.bat not found at $server" }

Write-Host "Starting Hop Server on http://localhost:8080  (Ctrl+C to stop)" -ForegroundColor Cyan
& $server -p 8080 -u cluster -p cluster 2>&1