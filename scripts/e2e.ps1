# Run E2E sandbox tests
$ErrorActionPreference = "Stop"
$wsbPath = "$PSScriptRoot\..\tests\sandbox.wsb"
if (-not (Test-Path $wsbPath)) {
    Write-Error "sandbox.wsb not found"
    exit 1
}
Write-Host "Launching Windows Sandbox..." -ForegroundColor Cyan
Start-Process $wsbPath
Write-Host "Sandbox launched. Check tests\results\ for output."
