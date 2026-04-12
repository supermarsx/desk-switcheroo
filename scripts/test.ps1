# Run the test suite (prefer x64 for DLL compatibility)
$ErrorActionPreference = "Stop"
if ($env:AUTOIT_PATH) {
    $AutoIt = "$env:AUTOIT_PATH\AutoIt3_x64.exe"
    if (-not (Test-Path $AutoIt)) { $AutoIt = "$env:AUTOIT_PATH\AutoIt3.exe" }
} else {
    $AutoIt = "C:\Program Files (x86)\AutoIt3\AutoIt3_x64.exe"
    if (-not (Test-Path $AutoIt)) {
        $AutoIt = "C:\Program Files (x86)\AutoIt3\AutoIt3.exe"
    }
    if (-not (Test-Path $AutoIt)) {
        $AutoIt = "C:\Program Files\AutoIt3\AutoIt3_x64.exe"
    }
    if (-not (Test-Path $AutoIt)) {
        $AutoIt = "C:\Program Files\AutoIt3\AutoIt3.exe"
    }
}
if (-not (Test-Path $AutoIt)) {
    Write-Error "AutoIt3.exe not found. Install AutoIt first."
    exit 1
}
Write-Host "Using: $AutoIt" -ForegroundColor Cyan
Write-Host "Running tests..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $AutoIt -ArgumentList "/ErrorStdOut", "$PSScriptRoot\..\tests\TestRunner.au3" -Wait -PassThru -NoNewWindow
exit $proc.ExitCode
