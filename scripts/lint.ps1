# Lint all AutoIt source files with au3check
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
$root = "$PSScriptRoot\.."
$files = Get-ChildItem -Path $root -Filter "*.au3" -Recurse | Where-Object { $_.FullName -notmatch "\\build\\" }
$errors = 0
foreach ($f in $files) {
    Write-Host "Checking $($f.Name)..." -NoNewline
    $output = & $au3check $f.FullName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host $output
        $errors++
    } else {
        Write-Host " OK" -ForegroundColor Green
    }
}
if ($errors -gt 0) {
    Write-Error "$errors file(s) had lint errors"
    exit 1
}
Write-Host "All files passed lint." -ForegroundColor Green
