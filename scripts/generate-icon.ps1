# Generate application icon using GDI+ via AutoIt
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

$script = Join-Path $root "tools\generate_icon.au3"
if (-not (Test-Path $script)) { Write-Error "generate_icon.au3 not found at $script"; exit 1 }

$assetsDir = Join-Path $root "assets"
New-Item -Path $assetsDir -ItemType Directory -Force | Out-Null

Write-Host "Generating icon..." -ForegroundColor Cyan
& $au3 $script
if ($LASTEXITCODE -ne 0) { Write-Error "Icon generation failed"; exit 1 }

$icoPath = Join-Path $assetsDir "desk_switcheroo.ico"
if (Test-Path $icoPath) {
    $size = [math]::Round((Get-Item $icoPath).Length / 1KB, 1)
    Write-Host "Icon generated: $icoPath ($size KB)" -ForegroundColor Green
} else {
    Write-Warning "Icon file not found after generation"
}
