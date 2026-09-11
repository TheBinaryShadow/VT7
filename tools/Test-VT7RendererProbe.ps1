[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$executable = Join-Path $BinaryDirectory 'VT7.RendererProbe.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw "Missing renderer probe: $executable" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

function Invoke-ProbeTest([string]$Arguments, [int]$ExpectedExit) {
    $process = Start-Process -FilePath $executable -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    try {
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            throw 'Renderer probe exceeded its 60-second timeout.'
        }
        if ($process.ExitCode -ne $ExpectedExit) { throw "Renderer probe exit $($process.ExitCode), expected $ExpectedExit. See $reportRoot" }
    }
    finally { $process.Dispose() }
}

$reportPath = Join-Path $reportRoot 'renderer-probe.log'
$started = Get-Date
Invoke-ProbeTest ('--output "' + $reportPath + '"') 0
if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTime -lt $started.AddSeconds(-2)) {
    throw 'Renderer probe did not produce a fresh report.'
}
$text = [IO.File]::ReadAllText($reportPath)
if ($text -notmatch '(?m)^Baseline passed: True\r?$' -or $text -match '(?m)^FAIL:') { throw 'Renderer baseline did not pass.' }
foreach ($mode in @('Hardware', 'WARP')) {
    foreach ($check in @('HWND discard/stretch swap chain', 'nonempty glyph pixel readback', 'resize buffers')) {
        if ($text -notmatch ('(?m)^PASS: ' + [regex]::Escape("$mode $check") + ' = 0x00000000\r?$')) {
            throw "Renderer report is missing $mode $check."
        }
    }
}
if ($text -notmatch '(?m)^PASS: Glyph callbacks cover sample UTF-16 text = 0x00000000\r?$') { throw 'Font layout check is missing.' }
foreach ($marker in @('Original 0.1 sample diagnostics', 'Source UTF16:', 'Source scalars:', 'family=', 'SHA256=', 'MAP:', 'PASS: Mapping oracles', 'PASS: Synthetic missing-glyph source association', 'PASS: Retained runs survive layout destruction and basic core-cell mapping')) {
    if (-not $text.Contains($marker)) { throw "Missing font diagnostic: $marker" }
}
$fixtureMatch = [regex]::Match($text, '(?m)^Font fixtures: 13; mapped=13; unresolved=0\r?$')
if (-not $fixtureMatch.Success) { throw 'Invalid font fixture accounting.' }
foreach ($marker in @('PASS: Private font loading, pinned hashes, BMP/SMP coverage and absent scalar',
    'PASS: Private fallback rejects combining, scripts, ZWJ sequences and unpaired surrogates',
    'PRIVATE_FALLBACK: forced-test scalars=U+262F face=Unifont',
    'PRIVATE_FALLBACK: forced-test scalars=U+01F600 face=Unifont Upper')) {
    if (-not $text.Contains($marker)) { throw "Missing private font check: $marker" }
}
& (Join-Path $PSScriptRoot 'Verify-VT7Fonts.ps1') -FontDirectory (Join-Path $BinaryDirectory 'fonts')
foreach ($marker in @('COVERAGE_RESULT:', 'EXPLICIT_COVERAGE:', 'PASS: Coverage status oracles', 'PASS: Whole-ink fitting oracles',
    'PASS: Visual-run ordering and logical/visual cell round-trip oracles', 'FIT:', 'RTL_GROUP:', 'Fixture: Arabic-mixed', 'Fixture: Arabic-marks')) {
    if (-not $text.Contains($marker)) { throw "Missing coverage/fitting/bidi diagnostic: $marker" }
}
$coverage = [regex]::Match($text, '(?m)^COVERAGE_RESULT: fonts=(\d+) supportingFaces=(\d+) errors=(\d+) status=(FOUND|NONE_IN_COLLECTION|INDETERMINATE)\r?$')
if (-not $coverage.Success -or [int]$coverage.Groups[1].Value -lt 1) { throw 'Invalid coverage scan accounting.' }
if ([int]$coverage.Groups[2].Value -gt 0) {
    if ($coverage.Groups[4].Value -ne 'FOUND' -or -not $text.Contains('EXPLICIT_COVERAGE: drawn nonzero')) { throw 'Covered face was not explicitly drawn.' }
} elseif ($coverage.Groups[4].Value -ne $(if ([int]$coverage.Groups[3].Value -gt 0) { 'INDETERMINATE' } else { 'NONE_IN_COLLECTION' })) {
    throw 'Absent and indeterminate coverage were confused.'
}
$bitmapPath = $reportPath + '.bmp'
if (-not $text.Contains('PASS: Natural-size and bounded-overhang oracles')) { throw 'Missing natural-size oracles.' }
foreach ($fixture in @('Latin-combining', 'Italic')) {
    if ($text -notmatch ('(?m)^FIT_FIXTURE: ' + $fixture + ' natural=[1-9]\d* compressed=0\r?$')) { throw "Natural-size regression: $fixture" }
}
$fitRecords = [regex]::Matches($text, '(?m)^FIT:.*scale=([\d.]+) policy=(natural|compressed) guard=(\d+) cellPixels=\[([\d.]+),([\d.]+)\) drawn=\[(-?[\d.]+),(-?[\d.]+)\)\r?$')
if ($fitRecords.Count -lt 60) { throw 'Missing fitted draw records.' }
foreach ($fitRecord in $fitRecords) {
    $fitScale = [double]::Parse($fitRecord.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
    $fitGuard = [int]$fitRecord.Groups[3].Value
    if ($fitRecord.Groups[2].Value -eq 'natural') {
        if ($fitScale -ne 1 -or $fitGuard -ne 2) { throw 'Natural path changed glyph proportions or guard.' }
    } elseif ($fitScale -le 0 -or $fitScale -gt 1 -or $fitGuard -ne 0) { throw 'Invalid compressed fit.' }
    $cellLeft = [double]::Parse($fitRecord.Groups[4].Value, [Globalization.CultureInfo]::InvariantCulture)
    $cellRight = [double]::Parse($fitRecord.Groups[5].Value, [Globalization.CultureInfo]::InvariantCulture)
    $inkLeft = [int]$fitRecord.Groups[6].Value
    $inkRight = [int]$fitRecord.Groups[7].Value
    if ($inkRight -gt $inkLeft -and ($inkLeft -lt $cellLeft - $fitGuard -or $inkRight -gt $cellRight + $fitGuard)) { throw 'Ink exceeded declared damage bounds.' }
}
if (-not (Test-Path -LiteralPath $bitmapPath) -or (Get-Item $bitmapPath).LastWriteTime -lt $started.AddSeconds(-2)) { throw 'Missing or stale font bitmap.' }
$bitmap = [IO.File]::ReadAllBytes($bitmapPath)
if ($bitmap.Length -ne 6160054 -or [Text.Encoding]::ASCII.GetString($bitmap, 0, 2) -ne 'BM' -or
    [BitConverter]::ToInt32($bitmap, 18) -ne 1100 -or [BitConverter]::ToInt32($bitmap, 22) -ne -1400) { throw 'Invalid top-down font bitmap.' }
& (Join-Path $PSScriptRoot 'Test-VT7Geometry.ps1') -ReportPath $reportPath -Started $started
& (Join-Path $PSScriptRoot 'Test-VT7Repaint.ps1') -ReportPath $reportPath -Started $started
& (Join-Path $PSScriptRoot 'Test-VT7TextAdapter.ps1') -ReportPath $reportPath -Started $started

$adapterPath = Join-Path $reportRoot 'renderer-probe-adapter-failure.log'
$adapterStarted = Get-Date
Invoke-ProbeTest ('--output "' + $adapterPath + '" --inject-adapter-failure') 1
if (-not (Test-Path -LiteralPath $adapterPath) -or (Get-Item -LiteralPath $adapterPath).LastWriteTime -lt $adapterStarted.AddSeconds(-2)) { throw 'Missing/stale adapter failure report.' }
$adapterText = [IO.File]::ReadAllText($adapterPath)
if ($adapterText -notmatch '(?m)^Baseline passed: False\r?$' -or $adapterText -notmatch 'Stale text mapper snapshot') { throw 'Stale adapter input did not fail the baseline.' }

$mappingPath = Join-Path $reportRoot 'renderer-probe-mapping-failure.log'
$mappingStarted = Get-Date
Invoke-ProbeTest ('--output "' + $mappingPath + '" --inject-font-failure') 1
if (-not (Test-Path $mappingPath) -or (Get-Item $mappingPath).LastWriteTime -lt $mappingStarted.AddSeconds(-2)) { throw 'Missing/stale mapping failure report.' }
$mappingText = [IO.File]::ReadAllText($mappingPath)
if ($mappingText -notmatch '(?m)^Baseline passed: False\r?$' -or $mappingText -notmatch 'Invalid retained cluster index') { throw 'Invalid mapping was not rejected.' }

$negativePath = Join-Path $reportRoot 'renderer-probe-injected-failure.log'
$negativeStarted = Get-Date
Invoke-ProbeTest ('--output "' + $negativePath + '" --inject-required-failure') 1
if (-not (Test-Path -LiteralPath $negativePath) -or (Get-Item -LiteralPath $negativePath).LastWriteTime -lt $negativeStarted.AddSeconds(-2)) {
    throw 'Negative probe did not produce a fresh report.'
}
$negative = [IO.File]::ReadAllText($negativePath)
if ($negative -notmatch '(?m)^Baseline passed: False\r?$' -or $negative -notmatch '(?m)^FAIL: Injected baseline failure') {
    throw 'Required failure was not reflected in the report.'
}
Invoke-ProbeTest '--invalid-option' 64
Invoke-ProbeTest ('--output "' + $reportRoot + '"') 2
# Never remove or damage the real assets. Exercise failures in a unique copy.
$privateTestRoot = Join-Path $reportRoot ('private-font-negative-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $privateTestRoot -Force | Out-Null
Copy-Item -LiteralPath $executable -Destination $privateTestRoot
Get-ChildItem -LiteralPath $BinaryDirectory -Filter '*.dll' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $privateTestRoot }
$originalExecutable = $executable
try {
    $executable = Join-Path $privateTestRoot 'VT7.RendererProbe.exe'
    $privateMissingLog = Join-Path $privateTestRoot 'missing-font.log'
    Invoke-ProbeTest ('--output "' + $privateMissingLog + '"') 1
    if ([IO.File]::ReadAllText($privateMissingLog) -notmatch 'Font file cannot be read') { throw 'Missing private font not reported.' }
    New-Item -ItemType Directory -Path (Join-Path $privateTestRoot 'fonts') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $BinaryDirectory 'fonts\unifont-17.0.05.otf') -Destination (Join-Path $privateTestRoot 'fonts')
    $privateUpperMissingLog = Join-Path $privateTestRoot 'missing-upper-font.log'
    Invoke-ProbeTest ('--output "' + $privateUpperMissingLog + '"') 1
    if ([IO.File]::ReadAllText($privateUpperMissingLog) -notmatch 'Font file cannot be read') { throw 'Missing Upper font not reported.' }
    # An existing non-font file is a deterministic wrong-hash fixture, not edited font data.
    # DirectWrite can retain a mapped font file after the probe exits. Use a new
    # location instead of overwriting any file that DirectWrite has opened.
    $privateBadRoot = Join-Path $privateTestRoot 'bad-hash-case'
    New-Item -ItemType Directory -Path (Join-Path $privateBadRoot 'fonts') -Force | Out-Null
    Copy-Item -LiteralPath $originalExecutable -Destination $privateBadRoot
    Get-ChildItem -LiteralPath $BinaryDirectory -Filter '*.dll' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $privateBadRoot }
    $executable = Join-Path $privateBadRoot 'VT7.RendererProbe.exe'
    Copy-Item -LiteralPath (Join-Path $BinaryDirectory 'fonts\README.md') -Destination (Join-Path $privateBadRoot 'fonts\unifont-17.0.05.otf')
    $privateBadLog = Join-Path $privateTestRoot 'bad-font-hash.log'
    Invoke-ProbeTest ('--output "' + $privateBadLog + '"') 1
    if ([IO.File]::ReadAllText($privateBadLog) -notmatch 'Private font SHA256 mismatch') { throw 'Altered private font not rejected.' }
} finally { $executable = $originalExecutable }
Write-Host "PASS: private font missing/hash-failure tests ($privateTestRoot)"
Write-Host "PASS: renderer hardware/WARP, retained font runs, core-cell mapping, bitmap, resize, and negative mapping/CLI/report checks ($reportPath)"
