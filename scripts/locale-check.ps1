# Verify all locale files have complete key coverage against en-US.ini
$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { Resolve-Path "$PSScriptRoot\.." } else { Get-Location }
$localesDir = Join-Path $root "locales"

$refFile = Join-Path $localesDir "en-US.ini"
if (-not (Test-Path $refFile)) { Write-Error "Reference locale en-US.ini not found"; exit 1 }

# Parse INI keys (section.key format)
function Get-IniKeys($path) {
    $keys = @()
    $section = ""
    foreach ($line in Get-Content $path) {
        $line = $line.Trim()
        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1]
        } elseif ($line -match '^([^;=]+)=') {
            $key = $Matches[1].Trim()
            if ($section -ne "Meta") {
                $keys += "$section.$key"
            }
        }
    }
    return $keys
}

$refKeys = Get-IniKeys $refFile
Write-Host "Reference: en-US.ini ($($refKeys.Count) keys)" -ForegroundColor Cyan

$localeFiles = Get-ChildItem -Path $localesDir -Filter "*.ini" | Where-Object { $_.Name -ne "en-US.ini" }
$hasErrors = $false

foreach ($f in $localeFiles) {
    $langKeys = Get-IniKeys $f.FullName
    $missing = $refKeys | Where-Object { $_ -notin $langKeys }
    $extra = $langKeys | Where-Object { $_ -notin $refKeys }

    if ($missing.Count -eq 0 -and $extra.Count -eq 0) {
        Write-Host "$($f.Name): OK ($($langKeys.Count) keys)" -ForegroundColor Green
    } else {
        $hasErrors = $true
        Write-Host "$($f.Name): ISSUES" -ForegroundColor Red
        if ($missing.Count -gt 0) {
            Write-Host "  Missing ($($missing.Count)):" -ForegroundColor Yellow
            foreach ($k in $missing) { Write-Host "    - $k" }
        }
        if ($extra.Count -gt 0) {
            Write-Host "  Extra ($($extra.Count)):" -ForegroundColor Yellow
            foreach ($k in $extra) { Write-Host "    + $k" }
        }
    }
}

if ($localeFiles.Count -eq 0) {
    Write-Host "No translation files found (only en-US.ini)" -ForegroundColor Yellow
}

Write-Host ""
if ($hasErrors) {
    Write-Host "LOCALE CHECK FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All locales complete" -ForegroundColor Green
}
