# Install the official portable AutoIt bundle and expose AUTOIT_PATH.
param(
    [string]$DownloadUrl = "https://www.autoitscript.com/files/autoit3/autoit-v3.zip",
    [string]$InstallRoot = $(if ($env:RUNNER_TEMP) {
            Join-Path $env:RUNNER_TEMP "autoit"
        } else {
            Join-Path ([System.IO.Path]::GetTempPath()) "desk-switcheroo-autoit"
        })
)

$ErrorActionPreference = "Stop"

$portableRoot = Join-Path $InstallRoot "install"
$requiredFiles = @(
    (Join-Path $portableRoot "Au3Check.exe"),
    (Join-Path $portableRoot "AutoIt3.exe"),
    (Join-Path $portableRoot "AutoIt3_x64.exe"),
    (Join-Path $portableRoot "Aut2Exe\Aut2exe.exe")
)

$isInstalled = $true
foreach ($path in $requiredFiles) {
    if (-not (Test-Path $path)) {
        $isInstalled = $false
        break
    }
}

if (-not $isInstalled) {
    New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null
    $zipPath = Join-Path $InstallRoot "autoit-v3.zip"

    Write-Host "Downloading AutoIt portable package from $DownloadUrl" -ForegroundColor Cyan
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipPath

    if (Test-Path $portableRoot) {
        Remove-Item $portableRoot -Recurse -Force
    }

    Expand-Archive -Path $zipPath -DestinationPath $InstallRoot -Force
}

foreach ($path in $requiredFiles) {
    if (-not (Test-Path $path)) {
        Write-Error "AutoIt install is incomplete. Missing: $path"
        exit 1
    }
}

$env:AUTOIT_PATH = $portableRoot
Write-Host "Using AUTOIT_PATH=$portableRoot" -ForegroundColor Green

if ($env:GITHUB_ENV) {
    Add-Content -Path $env:GITHUB_ENV -Value "AUTOIT_PATH=$portableRoot"
}
