# Install Desk Switcheroo: copy build output to a target directory
param(
    [string]$Destination = "$env:LOCALAPPDATA\DeskSwitcheroo"
)
$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { Resolve-Path "$PSScriptRoot\.." } else { Get-Location }
$buildDir = Join-Path $root "build"

# Build first if needed
if (-not (Test-Path (Join-Path $buildDir "DeskSwitcheroo.exe"))) {
    Write-Host "No build found. Building..." -ForegroundColor Yellow
    & pwsh (Join-Path $root "scripts\build.ps1")
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

Write-Host "Installing to: $Destination" -ForegroundColor Cyan
New-Item -Path $Destination -ItemType Directory -Force | Out-Null

# Copy files
$files = @("DeskSwitcheroo.exe", "VirtualDesktopAccessor.dll", "VERSION")
foreach ($f in $files) {
    $src = Join-Path $buildDir $f
    if (Test-Path $src) {
        Copy-Item $src $Destination -Force
        Write-Host "  Copied: $f"
    }
}

# Copy fonts
$fontsDir = Join-Path $buildDir "fonts"
if (Test-Path $fontsDir) {
    Copy-Item $fontsDir (Join-Path $Destination "fonts") -Recurse -Force
    Write-Host "  Copied: fonts\"
}

# Copy locales
$localesDir = Join-Path $root "locales"
if (Test-Path $localesDir) {
    Copy-Item $localesDir (Join-Path $Destination "locales") -Recurse -Force
    Write-Host "  Copied: locales\"
}

# Copy examples
$examplesDir = Join-Path $buildDir "examples"
if (Test-Path $examplesDir) {
    Copy-Item $examplesDir (Join-Path $Destination "examples") -Recurse -Force
    Write-Host "  Copied: examples\"
}

Write-Host "`nInstalled to: $Destination" -ForegroundColor Green
Write-Host "Run: $Destination\DeskSwitcheroo.exe"
