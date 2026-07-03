# Lint the AutoIt aggregate roots with Au3Check, exactly as CI does.
#
# The sources use relative #include paths that only resolve from their own
# directory, so linting each .au3 file standalone fails to find cross-includes.
# CI (.github/workflows/ci.yml) instead checks the two aggregate roots that
# pull in everything transitively:
#   1. desktop_switcher.au3   (from the repo root)
#   2. tests/TestRunner.au3    (from inside tests/, so its relative includes resolve)
# This script mirrors that and aggregates the exit codes.
$ErrorActionPreference = "Stop"
if ($env:AUTOIT_PATH) {
    $au3check = "$env:AUTOIT_PATH\Au3Check.exe"
} else {
    $au3check = "C:\Program Files (x86)\AutoIt3\Au3Check.exe"
    if (-not (Test-Path $au3check)) {
        $au3check = "C:\Program Files\AutoIt3\Au3Check.exe"
    }
}
if (-not (Test-Path $au3check)) {
    Write-Warning "Au3Check.exe not found. Skipping lint."
    exit 0
}

$root = Resolve-Path "$PSScriptRoot\.."
$errors = 0

function Invoke-Au3Check {
    param(
        [string]$WorkingDir,
        [string]$File
    )
    Write-Host "Checking $File..." -NoNewline
    Push-Location $WorkingDir
    try {
        $output = & $au3check $File 2>&1
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($code -ne 0) {
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host $output
        return $false
    }
    Write-Host " OK" -ForegroundColor Green
    return $true
}

# Root 1: main script, checked from the repo root.
if (-not (Invoke-Au3Check -WorkingDir $root -File "desktop_switcher.au3")) { $errors++ }

# Root 2: test runner, checked from inside tests/ so its relative includes resolve.
if (-not (Invoke-Au3Check -WorkingDir (Join-Path $root "tests") -File "TestRunner.au3")) { $errors++ }

if ($errors -gt 0) {
    Write-Error "$errors root(s) had lint errors"
    exit 1
}
Write-Host "All roots passed lint." -ForegroundColor Green
