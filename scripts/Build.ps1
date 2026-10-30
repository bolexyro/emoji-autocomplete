param([string]$Ahk2Exe = '', [string]$BaseFile = '')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'EmojiAutocomplete.ahk'
$dist = Join-Path $root 'dist\EmojiAutocomplete'

if (-not $Ahk2Exe) {
    $candidates = @(
        "$env:ProgramFiles\AutoHotkey\Compiler\Ahk2Exe.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\Compiler\Ahk2Exe.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"
    )
    $Ahk2Exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $Ahk2Exe -or -not (Test-Path -LiteralPath $Ahk2Exe)) {
    throw 'Ahk2Exe.exe was not found. Install AutoHotkey v2 with the compiler, or pass -Ahk2Exe <path>.'
}

if (-not $BaseFile) {
    $baseCandidates = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey32.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe"
    )
    $BaseFile = $baseCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $BaseFile -or -not (Test-Path -LiteralPath $BaseFile)) {
    throw 'An AutoHotkey v2 base runtime was not found. Pass -BaseFile <path-to-AutoHotkey64.exe>.'
}

New-Item -ItemType Directory -Force -Path $dist | Out-Null
$output = Join-Path $dist 'EmojiAutocomplete.exe'
if (Test-Path -LiteralPath $output) {
    try {
        Remove-Item -LiteralPath $output -Force -ErrorAction Stop
    } catch {
        throw 'Cannot replace EmojiAutocomplete.exe because it is running. Exit it from the tray and run the build again.'
    }
}
$arguments = @('/in', $source, '/out', $output, '/base', $BaseFile, '/silent', 'verbose')
& $Ahk2Exe @arguments
for ($attempt = 0; $attempt -lt 50 -and -not (Test-Path -LiteralPath $output); $attempt++) {
    Start-Sleep -Milliseconds 100
}
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $output)) {
    throw "Compilation failed with exit code $LASTEXITCODE"
}

Copy-Item -Recurse -Force (Join-Path $root 'data') $dist
Copy-Item -Recurse -Force (Join-Path $root 'config') $dist
Copy-Item -Recurse -Force (Join-Path $root 'assets') $dist
Copy-Item -Force (Join-Path $root 'README.md') $dist
Copy-Item -Force (Join-Path $root 'LICENSE') $dist
Copy-Item -Force (Join-Path $root 'THIRD_PARTY_NOTICES.md') $dist
Compress-Archive -Path "$dist\*" -DestinationPath (Join-Path $root 'dist\EmojiAutocomplete-Windows.zip') -Force
Write-Host "Built: $output"
Write-Host "Package: $(Join-Path $root 'dist\EmojiAutocomplete-Windows.zip')"
