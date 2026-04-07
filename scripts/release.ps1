# Create a new version tag in YY.N format and push
$ErrorActionPreference = "Stop"
$year = (Get-Date).ToString("yy")

# Find latest tag for this year
$tags = git tag -l "v${year}.*" --sort=-v:refname 2>$null
if ($tags) {
    $latest = ($tags | Select-Object -First 1) -replace "^v", ""
    $parts = $latest -split "\."
    $nextN = [int]$parts[1] + 1
} else {
    $nextN = 1
}

$version = "${year}.${nextN}"
$tag = "v${version}"

Write-Host "Creating release $tag..." -ForegroundColor Cyan
git tag -a $tag -m "Release $version"
git push origin $tag
Write-Host "Tag $tag pushed." -ForegroundColor Green
