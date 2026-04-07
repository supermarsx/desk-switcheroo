# Normalize line endings and trailing whitespace in .au3 files
$root = "$PSScriptRoot\.."
$files = Get-ChildItem -Path $root -Filter "*.au3" -Recurse | Where-Object { $_.FullName -notmatch "\\build\\" }
$fixed = 0
foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName)
    $original = $content
    # Normalize to CRLF
    $content = $content -replace "`r?`n", "`r`n"
    # Trim trailing whitespace per line
    $content = ($content -split "`r`n" | ForEach-Object { $_.TrimEnd() }) -join "`r`n"
    # Ensure final newline
    if (-not $content.EndsWith("`r`n")) { $content += "`r`n" }
    if ($content -ne $original) {
        [System.IO.File]::WriteAllText($f.FullName, $content)
        Write-Host "Fixed: $($f.Name)" -ForegroundColor Yellow
        $fixed++
    }
}
Write-Host "$fixed file(s) formatted." -ForegroundColor Cyan
