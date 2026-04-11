# Clean build artifacts and temporary files
$root = if ($PSScriptRoot) { Resolve-Path "$PSScriptRoot\.." } else { Get-Location }

$targets = @(
    (Join-Path $root "build"),
    (Join-Path $root "desk_switcheroo_state.ini"),
    (Join-Path $root "test_output.txt")
)

# Clean crash logs
$crashLogs = Get-ChildItem -Path $root -Filter "crash_*.log" -ErrorAction SilentlyContinue

$removed = 0
foreach ($t in $targets) {
    if (Test-Path $t) {
        Remove-Item $t -Recurse -Force
        Write-Host "Removed: $t" -ForegroundColor Yellow
        $removed++
    }
}
foreach ($f in $crashLogs) {
    Remove-Item $f.FullName -Force
    Write-Host "Removed: $($f.Name)" -ForegroundColor Yellow
    $removed++
}

# Clean log files
$logFiles = Get-ChildItem -Path $root -Filter "*.log" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "desk_switcheroo*" }
foreach ($f in $logFiles) {
    Remove-Item $f.FullName -Force
    Write-Host "Removed: $($f.Name)" -ForegroundColor Yellow
    $removed++
}

if ($removed -eq 0) {
    Write-Host "Nothing to clean" -ForegroundColor Green
} else {
    Write-Host "`nCleaned $removed item(s)" -ForegroundColor Green
}
