# =============================================================================
# scripts/trigger.ps1  -  triggers a pipeline/workflow through Hop Server REST.
# Requires Hop Server running (scripts/start-hop-server.ps1).
# =============================================================================
param(
    [string]$Name = "pipelines\01_check_drive.hpl",
    [string]$Config = "local",
    [string]$Server = "http://localhost:8080",
    [string]$User = "cluster",
    [string]$Password = "cluster"
)

$ErrorActionPreference = "Stop"
$enc = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${User}:${Password}"))
$headers = @{ Authorization = "Basic $enc" }
$uri = "$Server/hop/runPipeline/?name=$([Uri]::EscapeDataString($Name))&config=$Config"

Write-Host "POST $uri"
$resp = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -TimeoutSec 30
$resp | ConvertTo-Json -Depth 5