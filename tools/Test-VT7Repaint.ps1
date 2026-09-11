[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath, [datetime]$Started = [datetime]::MinValue)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repaintText = [IO.File]::ReadAllText($ReportPath)
$freshAfter = if ($Started -eq [datetime]::MinValue) { $Started } else { $Started.AddSeconds(-2) }
function Read-RepaintBitmap([string]$Path, [int]$Width, [int]$Height) {
    if (-not (Test-Path -LiteralPath $Path) -or (Get-Item -LiteralPath $Path).LastWriteTime -lt $freshAfter) { throw "Missing/stale repaint bitmap: $Path" }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ne 54 + 4 * $Width * $Height -or [Text.Encoding]::ASCII.GetString($bytes,0,2) -ne 'BM' -or
        [BitConverter]::ToInt32($bytes,18) -ne $Width -or [BitConverter]::ToInt32($bytes,22) -ne -$Height) { throw "Invalid repaint bitmap: $Path" }
    return ,$bytes
}
function Test-RepaintImages([string]$Prefix,[int]$Width,[int]$Height,[bool]$Negative) {
    $full = Read-RepaintBitmap ($Prefix + '.full.bmp') $Width $Height
    $incremental = Read-RepaintBitmap ($Prefix + '.incremental.bmp') $Width $Height
    $difference = Read-RepaintBitmap ($Prefix + '.difference.bmp') $Width $Height
    $mismatches = 0
    for ($pixel=54; $pixel -lt $full.Length; $pixel+=4) {
        $different = $full[$pixel] -ne $incremental[$pixel] -or $full[$pixel+1] -ne $incremental[$pixel+1] -or $full[$pixel+2] -ne $incremental[$pixel+2]
        if ($different) { $mismatches++ }
        $expectedRed = if ($different) { 255 } else { 0 }
        if ($difference[$pixel] -ne 0 -or $difference[$pixel+1] -ne 0 -or $difference[$pixel+2] -ne $expectedRed) { throw 'Repaint difference bitmap misrepresents pixels.' }
    }
    if (($Negative -and $mismatches -eq 0) -or (-not $Negative -and $mismatches -ne 0)) { throw "Unexpected repaint pixel comparison: $Prefix" }
    return $mismatches
}
$cases = [regex]::Matches($repaintText, '(?ms)^REPAINT_CASE: dip=(\d+) dpi=(\d+) bitmap=(\d+),(\d+) viewport=(\d+),(\d+),(\d+),(\d+)\r?\n(.*?)(?=^REPAINT_CASE:|^REPAINT_SUMMARY:)')
if ($cases.Count -ne 12) { throw 'Repaint matrix must contain exactly 12 cases.' }
$seen = @{}; $total = 0; $negative = 0; $imageTriples = 0
$names = @('marks-remove','marks-restore','neighbor-background','background-restore','italic-to-space','italic-restore',
    'narrow-to-wide','wide-to-narrow','combining-add','combining-remove','private-to-normal','private-restore',
    'foreground-change','foreground-restore','style-bold','style-restore','top-marks-remove','top-marks-restore','bottom-marks-remove','bottom-marks-restore')
foreach ($case in $cases) {
    $dip = [int]$case.Groups[1].Value; $dpi = [int]$case.Groups[2].Value; $key = "$dip-$dpi"
    if ($dip -notin 12,18,24 -or $dpi -notin 96,120,144,192 -or $seen.ContainsKey($key)) { throw 'Unexpected/duplicate repaint case.' }
    $seen[$key] = $true
    $width = [int]$case.Groups[3].Value; $height = [int]$case.Groups[4].Value
    $left = [int]$case.Groups[5].Value; $top = [int]$case.Groups[6].Value; $right = [int]$case.Groups[7].Value; $bottom = [int]$case.Groups[8].Value
    if ($left -ne 32 -or $top -ne 32 -or $right -ne $width-32 -or $bottom -ne $height-32) { throw 'Invalid repaint viewport.' }
    $body = $case.Groups[9].Value
    $steps = [regex]::Matches($body,'(?m)^REPAINT_STEP: generation=(\d+) name=([a-z-]+) damage=(\d+),(\d+),(\d+),(\d+) drawn=(\d+) available=(\d+) mismatch=0 outside=0 first=-1,-1\r?$')
    if ($steps.Count -ne 40) { throw "Repaint steps incomplete or failing: $key" }
    for ($step=0; $step -lt 40; $step++) {
        $record = $steps[$step]
        if ([int]$record.Groups[1].Value -ne $step+1 -or $record.Groups[2].Value -ne $names[$step % 20]) { throw 'Repaint generation/scenario mismatch.' }
        $dl=[int]$record.Groups[3].Value; $dt=[int]$record.Groups[4].Value; $dr=[int]$record.Groups[5].Value; $db=[int]$record.Groups[6].Value
        if ($dl -lt $left -or $dt -lt $top -or $dr -gt $right -or $db -gt $bottom -or $dl -ge $dr -or $dt -ge $db -or
            ($dl -eq $left -and $dt -eq $top -and $dr -eq $right -and $db -eq $bottom)) { throw 'Invalid/full-frame repaint damage.' }
        if ([int]$record.Groups[7].Value -ge [int]$record.Groups[8].Value) { throw 'Repaint silently redrew every glyph.' }
        $total++
    }
    $negatives = [regex]::Matches($body,'(?m)^REPAINT_NEGATIVE: kind=(omit-old-ink|omit-neighbors) mismatches=([1-9]\d*) first=(\d+),(\d+)\r?$')
    if ($negatives.Count -ne 2 -or $negatives[0].Groups[1].Value -ne 'omit-old-ink' -or $negatives[1].Groups[1].Value -ne 'omit-neighbors') { throw 'Negative repaint cases were not detected.' }
    $negative+=2
    if ([regex]::Matches($body,'(?m)^REPAINT_RESTORED: identical=1\r?$').Count -ne 1) { throw 'Repaint did not restore initial pixels.' }
    $prefix = $ReportPath + ".bmp.repaint-$key"
    $null = Test-RepaintImages ($prefix + '.sample') $width $height $false; $imageTriples++
    if ($dip -eq 24 -and $dpi -eq 192) {
        $old = Test-RepaintImages ($prefix + '.negative-old') $width $height $true
        $neighbors = Test-RepaintImages ($prefix + '.negative-neighbor') $width $height $true
        if ($old -ne [int]$negatives[0].Groups[2].Value -or $neighbors -ne [int]$negatives[1].Groups[2].Value) { throw 'Negative repaint log/pixel counts differ.' }
        $imageTriples+=2
    }
}
if (-not $repaintText.Contains("REPAINT_SUMMARY: cases=12 transitions=$total negativeDetected=$negative partialDraws=$total mismatches=0 outside=0") -or $total -ne 480 -or $negative -ne 24) { throw 'Repaint summary incomplete.' }
Write-Host "PASS: repaint 480 transitions, 24 detected negatives, partial damage/draw checks and $imageTriples independently compared bitmap triples."
