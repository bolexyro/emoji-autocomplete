$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$catalog = Join-Path $root 'data\emoji.tsv'
$outputDirectory = Join-Path $root 'assets\emoji'
$twemojiVersion = '15.1.0'

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

function Get-CodePointName([string]$Text) {
    $values = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $Text.Length; $index++) {
        $value = [char]::ConvertToUtf32($Text, $index)
        if ([char]::IsHighSurrogate($Text[$index])) { $index++ }
        # Twemoji asset names omit the emoji-presentation variation selector.
        if ($value -ne 0xFE0F) { $values.Add($value.ToString('x')) }
    }
    return $values -join '-'
}

$downloaded = 0
foreach ($line in Get-Content -LiteralPath $catalog -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    $columns = $line -split "`t"
    if ($columns.Count -lt 2) { continue }
    $emoji = $columns[0]
    $name = $columns[1]
    $assetName = Get-CodePointName $emoji
    $uri = "https://cdn.jsdelivr.net/gh/jdecked/twemoji@$twemojiVersion/assets/72x72/$assetName.png"
    $destination = Join-Path $outputDirectory "$name.png"
    Invoke-WebRequest -Uri $uri -OutFile $destination
    $downloaded++
}

Write-Host "Downloaded $downloaded Twemoji color assets to $outputDirectory"
