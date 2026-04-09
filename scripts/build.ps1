# Compile desktop_switcher.au3 to .exe using Aut2Exe
$ErrorActionPreference = "Stop"

# Resolve project root
$root = if ($PSScriptRoot) { Resolve-Path "$PSScriptRoot\.." } else { Get-Location }
$buildDir = Join-Path $root "build"

# Find Aut2Exe
$aut2exe = $null
$searchPaths = @()
if ($env:AUTOIT_PATH) { $searchPaths += "$env:AUTOIT_PATH\Aut2Exe\Aut2exe.exe" }
$searchPaths += "C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe"
$searchPaths += "C:\Program Files\AutoIt3\Aut2Exe\Aut2exe.exe"
# Also check choco install path
$searchPaths += "C:\ProgramData\chocolatey\lib\autoit\tools\install\Aut2Exe\Aut2exe.exe"

foreach ($p in $searchPaths) {
    if (Test-Path $p) { $aut2exe = $p; break }
}

if (-not $aut2exe) {
    # Try finding it via where.exe
    $found = Get-Command Aut2exe.exe -ErrorAction SilentlyContinue
    if ($found) { $aut2exe = $found.Source }
}

if (-not $aut2exe) {
    Write-Error "Aut2Exe not found. Install AutoIt first. Searched: $($searchPaths -join ', ')"
    exit 1
}

Write-Host "Using Aut2Exe: $aut2exe" -ForegroundColor Cyan

# Prepare build directory
New-Item -Path $buildDir -ItemType Directory -Force | Out-Null

# Build icon argument if icon exists
$iconArgs = @()
$iconPath = Join-Path $root "assets\desk_switcheroo.ico"
if (Test-Path $iconPath) {
    $iconArgs = @("/icon", $iconPath)
    Write-Host "Using icon: $iconPath"
}

# Compile
$srcPath = Join-Path $root "desktop_switcher.au3"
$outPath = Join-Path $buildDir "DeskSwitcheroo.exe"
Write-Host "Compiling $srcPath -> $outPath" -ForegroundColor Cyan

& $aut2exe /in $srcPath /out $outPath /x64 @iconArgs 2>&1 | Write-Host

# Verify output exists (Aut2Exe doesn't always set exit codes reliably)
Start-Sleep -Seconds 2
if (-not (Test-Path $outPath)) {
    Write-Error "Compilation failed — no output file at $outPath"
    exit 1
}
Write-Host "Compiled successfully: $outPath" -ForegroundColor Green

# Copy runtime dependencies
Copy-Item (Join-Path $root "VirtualDesktopAccessor.dll") $buildDir -Force
$fontsDir = Join-Path $root "fonts"
if (Test-Path $fontsDir) {
    Copy-Item $fontsDir (Join-Path $buildDir "fonts") -Recurse -Force
}
# Copy VERSION file
$versionFile = Join-Path $root "VERSION"
if (Test-Path $versionFile) {
    Copy-Item $versionFile $buildDir -Force
    Write-Host "Version: $(Get-Content $versionFile)" -ForegroundColor Cyan
}
# Copy examples
$examplesDir = Join-Path $root "examples"
if (Test-Path $examplesDir) {
    Copy-Item $examplesDir (Join-Path $buildDir "examples") -Recurse -Force
}

Write-Host "`nBuild complete:" -ForegroundColor Green
Get-ChildItem $buildDir -Recurse | ForEach-Object {
    $rel = $_.FullName.Replace("$buildDir\", "")
    Write-Host "  $rel ($([math]::Round($_.Length/1KB, 1)) KB)"
}
