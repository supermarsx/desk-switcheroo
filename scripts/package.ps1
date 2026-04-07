# Build + create NSIS installer + portable zip
$ErrorActionPreference = "Stop"
$root = "$PSScriptRoot\.."
$buildDir = "$root\build"

# Step 1: Build exe
Write-Host "=== Building executable ===" -ForegroundColor Cyan
& pwsh "$PSScriptRoot\build.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

# Step 2: Create portable zip
Write-Host "=== Creating portable zip ===" -ForegroundColor Cyan
$zipPath = "$buildDir\DeskSwitcheroo_Portable.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }
$tempPortable = "$buildDir\_portable"
New-Item -Path $tempPortable -ItemType Directory -Force | Out-Null
Copy-Item "$buildDir\DeskSwitcheroo.exe" "$tempPortable\"
Copy-Item "$buildDir\VirtualDesktopAccessor.dll" "$tempPortable\"
if (Test-Path "$buildDir\fonts") {
    Copy-Item "$buildDir\fonts" "$tempPortable\fonts" -Recurse
}
Compress-Archive -Path "$tempPortable\*" -DestinationPath $zipPath -Force
Remove-Item $tempPortable -Recurse -Force
Write-Host "Portable zip: $zipPath" -ForegroundColor Green

# Step 3: Build NSIS installer
Write-Host "=== Building NSIS installer ===" -ForegroundColor Cyan
$makensis = "C:\Program Files (x86)\NSIS\makensis.exe"
if (-not (Test-Path $makensis)) {
    $makensis = "C:\Program Files\NSIS\makensis.exe"
}
if (Test-Path $makensis) {
    & $makensis "$root\installer\desk_switcheroo.nsi"
    if ($LASTEXITCODE -ne 0) { Write-Error "NSIS build failed"; exit 1 }
    Write-Host "Installer: $buildDir\DeskSwitcheroo_Setup.exe" -ForegroundColor Green
} else {
    Write-Warning "NSIS not found. Skipping installer build."
}

Write-Host "`n=== Package complete ===" -ForegroundColor Green
Get-ChildItem "$buildDir\DeskSwitcheroo_*" | Format-Table Name, @{N="Size (KB)";E={[math]::Round($_.Length/1KB)}}
