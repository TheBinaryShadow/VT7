[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath, [datetime]$Started = [datetime]::MinValue)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$geometryText = [IO.File]::ReadAllText($ReportPath)
$freshAfter = if ($Started -eq [datetime]::MinValue) { $Started } else { $Started.AddSeconds(-2) }
$culture = [Globalization.CultureInfo]::InvariantCulture
function Read-Number([string]$Value) { return [double]::Parse($Value, $culture) }
function Test-InkRecord($Ink) {
    $x = [int]$Ink.Groups['x'].Value; $width = [int]$Ink.Groups['width'].Value
    $top = [int]$Ink.Groups['top'].Value; $height = [int]$Ink.Groups['height'].Value
    $halo = [int]$Ink.Groups['halo'].Value; $scale = Read-Number $Ink.Groups['scale'].Value
    $left = [int]$Ink.Groups['left'].Value; $right = [int]$Ink.Groups['right'].Value
    $inkTop = [int]$Ink.Groups['inkTop'].Value; $bottom = [int]$Ink.Groups['bottom'].Value
    if ($scale -le 0 -or $scale -gt 1 -or $width -le 2 -or $height -le 0) { throw 'Invalid geometry fit dimensions.' }
    if (($halo -ne 0 -and $halo -ne 2) -or ($halo -eq 2 -and $scale -ne 1)) { throw 'Invalid geometry fit halo.' }
    $nonempty = $right -gt $left -and $bottom -gt $inkTop
    if ($Ink.Groups['private'].Value -eq '1' -and -not $nonempty) { throw 'Private geometry glyph is empty.' }
    if ($nonempty -and ($left -lt $x - $halo -or $right -gt $x + $width + $halo)) { throw 'Geometry ink escaped horizontal bounds.' }
    $expectedStatus = if ($nonempty -and ($inkTop -lt $top -or $bottom -gt $top + $height)) { 'REVIEW' } else { 'FIT' }
    if ($Ink.Groups['vertical'].Value -ne $expectedStatus) { throw 'Vertical overflow misreported.' }
}
$inkPattern = '(?m)^GEOMETRY_INK: x=(?<x>\d+) width=(?<width>\d+) rowTop=(?<top>\d+) rowHeight=(?<height>\d+) baseline=\d+ scale=(?<scale>[\d.]+) halo=(?<halo>\d+) retries=\d+ original=-?\d+,-?\d+,-?\d+,-?\d+ drawn=(?<left>-?\d+),(?<inkTop>-?\d+),(?<right>-?\d+),(?<bottom>-?\d+) vertical=(?<vertical>REVIEW|FIT) private=(?<private>[01])\r?$'
$cases = [regex]::Matches($geometryText, '(?ms)^GEOMETRY_CASE: dip=(\d+) dpi=(\d+) ppd=([\d.]+) cell=(\d+),(\d+) baseline=(\d+) generation=(\d+) bitmap=(\d+),(\d+)\r?\n(.*?)(?=^GEOMETRY_CASE:|^GEOMETRY_TRANSITIONS:)')
if ($cases.Count -ne 12) { throw 'Geometry matrix must contain exactly 12 cases.' }
$seen = @{}; $referenceCells = $null; $verticalReviews = 0; $inkCount = 0
$design = [regex]::Match($geometryText, '(?m)^GEOMETRY_DESIGN: units=(\d+) ascent=(\d+) descent=(\d+) gap=(\d+) advance=(\d+)\r?$')
if (-not $design.Success -or [int]$design.Groups[1].Value -le 0) { throw 'Missing primary design metrics.' }
if (-not $geometryText.Contains('PASS: Optional glyph offsets retained as zero displacements')) { throw 'Optional-offset callback oracle missing.' }
foreach ($case in $cases) {
    $dip = [int]$case.Groups[1].Value; $dpi = [int]$case.Groups[2].Value
    $key = "$dip-$dpi"
    if ($dip -notin 12,18,24 -or $dpi -notin 96,120,144,192 -or $seen.ContainsKey($key)) { throw "Unexpected/duplicate geometry case $key" }
    $seen[$key] = $true
    if ((Read-Number $case.Groups[3].Value) -ne $dpi / 96.0) { throw 'Incorrect DIP conversion.' }
    $cellWidth = [int]$case.Groups[4].Value; $cellHeight = [int]$case.Groups[5].Value
    $baseline = [int]$case.Groups[6].Value
    if ($cellWidth -le 2 -or $baseline -le 0 -or $baseline -ge $cellHeight) { throw 'Invalid primary grid.' }
    $unit = $dip * ($dpi / 96.0) / [int]$design.Groups[1].Value
    $expectedBaseline = [math]::Ceiling([int]$design.Groups[2].Value * $unit)
    $expectedHeight = $expectedBaseline + [math]::Ceiling([int]$design.Groups[3].Value * $unit) + [math]::Ceiling([int]$design.Groups[4].Value * $unit)
    $expectedWidth = [math]::Floor([int]$design.Groups[5].Value * $unit + 0.5)
    if ($cellWidth -ne $expectedWidth -or $cellHeight -ne $expectedHeight -or $baseline -ne $expectedBaseline) { throw 'Primary grid rounding differs from declared policy.' }
    $body = $case.Groups[10].Value
    $fixtures = [regex]::Matches($body, '(?m)^GEOMETRY_FIXTURE: index=(\d+) name=')
    if ($fixtures.Count -ne 17) { throw "Geometry fixtures missing in $key" }
    for ($index = 0; $index -lt 17; $index++) { if ([int]$fixtures[$index].Groups[1].Value -ne $index) { throw 'Fixture order mismatch.' } }
    $cells = (@([regex]::Matches($body, '(?m)^GEOMETRY_CELL:.*$') | ForEach-Object { $_.Value.TrimEnd() }) -join "`n")
    if ($null -eq $referenceCells) { $referenceCells = $cells } elseif ($cells -ne $referenceCells) { throw 'Core source/cells changed across geometry cases.' }
    $inks = [regex]::Matches($body, $inkPattern)
    if ($inks.Count -lt 70) { throw "Missing geometry ink records in $key" }
    foreach ($ink in $inks) { Test-InkRecord $ink; $inkCount++; if ($ink.Groups['vertical'].Value -eq 'REVIEW') { $verticalReviews++ } }
    if ([regex]::Matches($body, '(?m)^GEOMETRY_CLIP: fixture=\d+ rect=\d+,\d+,\d+,\d+ destinationY=\d+ mismatches=0\r?$').Count -ne 17) { throw 'Crop/sentinel checks incomplete.' }
    if ([regex]::Matches($body, '(?m)^GEOMETRY_DECORATION:').Count -ne 2) { throw 'Decoration checks missing.' }
    if (-not $body.Contains('PRIVATE_FALLBACK: forced-test scalars=U+262F') -or -not $body.Contains('PRIVATE_FALLBACK: forced-test scalars=U+01F600')) { throw 'Private matrix fixture missing.' }
    $bitmapPath = $ReportPath + ".bmp.geometry-$key.bmp"
    if (-not (Test-Path -LiteralPath $bitmapPath) -or (Get-Item -LiteralPath $bitmapPath).LastWriteTime -lt $freshAfter) { throw "Missing/stale geometry bitmap $key" }
    $bytes = [IO.File]::ReadAllBytes($bitmapPath)
    $width = [int]$case.Groups[8].Value; $height = [int]$case.Groups[9].Value
    if ($bytes.Length -ne 54 + 4 * $width * $height -or [Text.Encoding]::ASCII.GetString($bytes,0,2) -ne 'BM' -or
        [BitConverter]::ToInt32($bytes,18) -ne $width -or [BitConverter]::ToInt32($bytes,22) -ne -$height) { throw 'Invalid geometry bitmap.' }
}
if (-not $geometryText.Contains('GEOMETRY_TRANSITIONS: changes=4 staleRejected=4 restoredEqualsInitial=1 restoredEqualsFresh=1')) { throw 'Geometry transition regression.' }
if (-not $geometryText.Contains("GEOMETRY_SUMMARY: cases=12 fixtures=204 verticalReviewDraws=$verticalReviews structuralFailures=0;")) { throw 'Geometry accounting differs.' }
# Prove the independent bound checker rejects a deliberately escaped glyph.
$negativeInk = [regex]::Match('GEOMETRY_INK: x=300 width=10 rowTop=70 rowHeight=20 baseline=85 scale=1 halo=2 retries=0 original=0,-10,9,0 drawn=297,75,310,85 vertical=FIT private=0', $inkPattern)
$rejected = $false
try { Test-InkRecord $negativeInk } catch { if ($_.Exception.Message -eq 'Geometry ink escaped horizontal bounds.') { $rejected = $true } else { throw } }
if (-not $rejected) { throw 'Geometry negative-bound oracle was accepted.' }
Write-Host "PASS: geometry 12 cases, 204 fixtures, $inkCount ink records; $verticalReviews vertical review observations; images, cells, transitions, crop and negative-bound checks."
