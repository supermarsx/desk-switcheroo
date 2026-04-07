# Run the test suite
$ErrorActionPreference = "Stop"
$AutoIt = "C:\Program Files (x86)\AutoIt3\AutoIt3.exe"
if (-not (Test-Path $AutoIt)) {
    $AutoIt = "C:\Program Files\AutoIt3\AutoIt3.exe"
}
if (-not (Test-Path $AutoIt)) {
    Write-Error "AutoIt3.exe not found. Install AutoIt first."
    exit 1
}
Write-Host "Running tests..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $AutoIt -ArgumentList "/ErrorStdOut", "$PSScriptRoot\..\tests\TestRunner.au3" -Wait -PassThru -NoNewWindow
exit $proc.ExitCode
