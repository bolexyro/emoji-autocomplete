$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$required = @(
    'EmojiAutocomplete.ahk',
    'data\emoji.tsv',
    'config\settings.ini',
    'THIRD_PARTY_NOTICES.md',
    'README.md',
    'LICENSE'
)

foreach ($relativePath in $required) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required file: $relativePath"
    }
}

$catalogPath = Join-Path $root 'data\emoji.tsv'
$entries = @()
$lineNumber = 0
foreach ($line in Get-Content -LiteralPath $catalogPath -Encoding UTF8) {
    $lineNumber++
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    $columns = $line -split "`t"
    if ($columns.Count -lt 2 -or [string]::IsNullOrWhiteSpace($columns[0]) -or [string]::IsNullOrWhiteSpace($columns[1])) {
        throw "Invalid catalog row at line $lineNumber"
    }
    if ($columns[1] -notmatch '^[a-z0-9_+\-]+$') {
        throw "Invalid canonical name '$($columns[1])' at line $lineNumber"
    }
    $entries += $columns[1]
}

if ($entries.Count -lt 25) { throw "Catalog is unexpectedly small: $($entries.Count) entries" }
$duplicates = $entries | Group-Object | Where-Object Count -gt 1
if ($duplicates) { throw "Duplicate canonical names: $(($duplicates.Name) -join ', ')" }

$assetDirectory = Join-Path $root 'assets\emoji'
$missingAssets = $entries | Where-Object { -not (Test-Path -LiteralPath (Join-Path $assetDirectory "$_.png")) }
if ($missingAssets) { throw "Missing color emoji assets: $($missingAssets -join ', ')" }

$source = Get-Content -LiteralPath (Join-Path $root 'EmojiAutocomplete.ahk') -Raw -Encoding UTF8
if ($source -notmatch '#Requires AutoHotkey v2\.0') { throw 'Source does not require AutoHotkey v2.0' }
if ($source -match '(?m)^\s*SendText\(.*query') { throw 'Validation detected possible eager shortcode replacement' }

Write-Host "Validation passed: $($entries.Count) emoji entries, color assets, and all required files are present."
