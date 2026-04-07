# Compile desktop_switcher.au3 to .exe using Aut2Exe
$ErrorActionPreference = "Stop"
$root = "$PSScriptRoot\.."
$buildDir = "$root\build"
$aut2exe = "C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe"
if (-not (Test-Path $aut2exe)) {
    $aut2exe = "C:\Program Files\AutoIt3\Aut2Exe\Aut2exe.exe"
}
if (-not (Test-Path $aut2exe)) {
    Write-Error "Aut2Exe not found. Install AutoIt first."
    exit 1
}

New-Item -Path $buildDir -ItemType Directory -Force | Out-Null

$iconArg = @()
$iconPath = "$root\assets\desk_switcheroo.ico"
if (Test-Path $iconPath) {
    $iconArg = @("/icon", $iconPath)
}

Write-Host "Compiling DeskSwitcheroo.exe..." -ForegroundColor Cyan
& $aut2exe /in "$root\desktop_switcher.au3" /out "$buildDir\DeskSwitcheroo.exe" /x64 @iconArg
if ($LASTEXITCODE -ne 0) { Write-Error "Compilation failed"; exit 1 }

# Copy runtime dependencies
Copy-Item "$root\VirtualDesktopAccessor.dll" "$buildDir\" -Force
if (Test-Path "$root\fonts") {
    Copy-Item "$root\fonts" "$buildDir\fonts" -Recurse -Force
}

Write-Host "Build complete: $buildDir" -ForegroundColor Green
Get-ChildItem $buildDir | Format-Table Name, Length
