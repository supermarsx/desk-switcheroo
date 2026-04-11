# Run the app directly from source (development mode)
$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { Resolve-Path "$PSScriptRoot\.." } else { Get-Location }

# Find AutoIt
$au3 = $null
$searchPaths = @(
    "C:\Program Files (x86)\AutoIt3\AutoIt3_x64.exe",
    "C:\Program Files (x86)\AutoIt3\AutoIt3.exe",
    "C:\Program Files\AutoIt3\AutoIt3_x64.exe"
)
if ($env:AUTOIT_PATH) { $searchPaths = @("$env:AUTOIT_PATH\AutoIt3_x64.exe") + $searchPaths }
foreach ($p in $searchPaths) {
    if (Test-Path $p) { $au3 = $p; break }
}
if (-not $au3) { Write-Error "AutoIt not found"; exit 1 }

$script = Join-Path $root "desktop_switcher.au3"
Write-Host "Running: $au3 $script" -ForegroundColor Cyan
& $au3 $script
