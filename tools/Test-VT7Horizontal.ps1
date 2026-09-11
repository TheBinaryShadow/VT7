[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath, [datetime]$Started = [datetime]::MinValue)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$text = [IO.File]::ReadAllText($ReportPath)
$culture = [Globalization.CultureInfo]::InvariantCulture
function Number([string]$value) { [double]::Parse($value,$culture) }
$freshAfter = if ($Started -eq [datetime]::MinValue) { $Started } else { $Started.AddSeconds(-2) }
$cases = [regex]::Matches($text,'(?ms)^HORIZONTAL_CASE: dip=(\d+) dpi=(\d+) grid=(\d+),(\d+) baseline=(\d+) canvas=(\d+),(\d+)\r?\n(.*?)^HORIZONTAL_CASE_END: fixtures=12 repaints=6\r?$')
if ($cases.Count -ne 12) { throw 'Horizontal matrix incomplete.' }
$seen=@{}; $groups=0; $compressed=0
$names=@('Emoji-neighbor','Private-BMP','Private-SMP','Latin','Italic','Bold','CJK-neighbor','Stacked-marks','Indic-neighbor','Arabic-mixed','Arabic-style','Hebrew-mixed')
$fixedSpans=@{}
foreach ($case in $cases) {
    $dip=[int]$case.Groups[1].Value; $dpi=[int]$case.Groups[2].Value; $key="$dip-$dpi"
    if ($seen.ContainsKey($key) -or $dip -notin @(12,18,24) -or $dpi -notin @(96,120,144,192)) { throw 'Invalid horizontal size/DPI configuration.' }
    $seen[$key]=$true
    $width=[int]$case.Groups[3].Value; $height=[int]$case.Groups[4].Value; $baseline=[int]$case.Groups[5].Value
    if ($width -le 0 -or $height -le 0 -or $baseline -lt 0 -or $baseline -gt $height) { throw 'Invalid horizontal grid.' }
    $fixtures=[regex]::Matches($case.Groups[8].Value,'(?ms)^HORIZONTAL_FIXTURE: index=(\d+) name=([^\r\n ]+) source=(\d+) cells=(\d+) groups=(\d+)\r?\n(.*?)^HORIZONTAL_RESULT: index=(\d+) source=unchanged protection=PASS\r?$')
    if ($fixtures.Count -ne 12) { throw 'Horizontal fixture count differs.' }
    for ($i=0; $i -lt 12; ++$i) {
        $fixture=$fixtures[$i]
        if ([int]$fixture.Groups[1].Value -ne $i -or [int]$fixture.Groups[7].Value -ne $i -or $fixture.Groups[2].Value -ne $names[$i]) { throw 'Horizontal fixture identity differs.' }
        $records=[regex]::Matches($fixture.Groups[6].Value,'(?m)^HORIZONTAL_GROUP: text=(\d+),(\d+) cells=(\d+),(\d+) width=(\d+) policy=(natural|compressed) scale=([\d.eE+\-]+) offset=([\d.eE+\-]+) halo=(\d+) retries=(\d+) scaleY=1 naturalInk=(-?\d+),(-?\d+),(-?\d+),(-?\d+) ink=(-?\d+),(-?\d+),(-?\d+),(-?\d+) changed=(\d+) outside=0\r?$')
        if ($records.Count -ne [int]$fixture.Groups[5].Value) { throw 'Horizontal glyph-group count differs.' }
        $source=0; $column=0; $signature=@()
        foreach ($record in $records) {
            $start=[int]$record.Groups[1].Value; $end=[int]$record.Groups[2].Value
            $first=[int]$record.Groups[3].Value; $last=[int]$record.Groups[4].Value; $allocation=[int]$record.Groups[5].Value
            $scale=Number $record.Groups[7].Value; $offset=Number $record.Groups[8].Value
            $halo=[int]$record.Groups[9].Value; $retries=[int]$record.Groups[10].Value
            $inkLeft=[int]$record.Groups[15].Value; $inkTop=[int]$record.Groups[16].Value
            $inkRight=[int]$record.Groups[17].Value; $inkBottom=[int]$record.Groups[18].Value
            $changed=[int]$record.Groups[19].Value
            if ($start -ne $source -or $end -le $source -or $first -ne $column -or $last -le $column -or $allocation -ne ($last-$first)*$width -or
                $scale -le 0 -or $scale -gt 1 -or $retries -gt 16) { throw 'Invalid horizontal group geometry.' }
            if ($record.Groups[6].Value -eq 'natural') {
                if ($scale -ne 1 -or $offset -ne 0 -or $halo -ne [math]::Ceiling($width/5.0) -or $retries -ne 0) { throw 'Natural fitting policy changed.' }
            } else {
                if ($halo -ne 0) { throw 'Compressed glyph permits spill.' }; ++$compressed
            }
            if ($inkRight -gt $inkLeft -and $inkBottom -gt $inkTop) {
                if ($inkLeft -lt -$halo -or $inkRight -gt $allocation+$halo -or $changed -le 0) { throw 'Fitted ink lost or escaped horizontal bounds.' }
            }
            $originalNonempty=([int]$record.Groups[13].Value -gt [int]$record.Groups[11].Value -and [int]$record.Groups[14].Value -gt [int]$record.Groups[12].Value)
            if ($originalNonempty -and $changed -le 0) { throw 'Originally nonempty group was erased.' }
            $signature += "$start,$end,$first,$last"
            $source=$end; $column=$last; ++$groups
        }
        if ($source -ne [int]$fixture.Groups[3].Value -or $column -ne [int]$fixture.Groups[4].Value) { throw 'Horizontal source/core coverage differs.' }
        $spanSignature=$signature -join ';'
        if ($fixedSpans.ContainsKey($i) -and $fixedSpans[$i] -ne $spanSignature) { throw 'Horizontal source/group spans changed with DPI.' }
        $fixedSpans[$i]=$spanSignature
        if ($i -in @(3,4) -and $fixture.Groups[6].Value -notmatch "(?m)^HORIZONTAL_NATURAL: index=$i rawPixels=identical\r?$") { throw 'Natural Latin/italic regression missing.' }
        if ($i -eq 1 -and ($fixture.Groups[6].Value -notmatch '(?m)^HORIZONTAL_NEGATIVE: unscaled-private escaped=[1-9]\d*\r?$' -or $records[0].Groups[6].Value -ne 'compressed')) { throw 'Oversized private negative control missing.' }
    }
    $repaints=[regex]::Matches($case.Groups[8].Value,'(?m)^HORIZONTAL_REPAINT: step=(\d+) damage=(\d+),(\d+),(\d+),(\d+) mismatches=0 outside=0\r?$')
    if ($repaints.Count -ne 6) { throw 'Horizontal repaint count differs.' }
    for ($i=0; $i -lt 6; ++$i) {
        $r=$repaints[$i]; $l=[int]$r.Groups[2].Value; $t=[int]$r.Groups[3].Value; $right=[int]$r.Groups[4].Value; $bottom=[int]$r.Groups[5].Value
        if ([int]$r.Groups[1].Value -ne $i -or $right -le $l -or $bottom -le $t -or $right -gt 512 -or $bottom -gt 256 -or ($right-$l)*($bottom-$t) -ge 512*256) { throw 'Horizontal damage is invalid or full frame.' }
    }
    $path=$ReportPath+".bmp.horizontal-$key.bmp"
    if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).LastWriteTime -lt $freshAfter) { throw "Missing/stale horizontal bitmap: $key" }
    $bytes=[IO.File]::ReadAllBytes($path); $cw=[int]$case.Groups[6].Value; $ch=[int]$case.Groups[7].Value
    if ($bytes.Length -ne 54+4*$cw*$ch -or [Text.Encoding]::ASCII.GetString($bytes,0,2) -ne 'BM' -or
        [BitConverter]::ToInt32($bytes,18) -ne $cw -or [BitConverter]::ToInt32($bytes,22) -ne -$ch) { throw 'Invalid horizontal bitmap.' }
}
if ($text -notmatch ("(?m)^HORIZONTAL_SUMMARY: cases=12 fixtures=144 groups=$groups compressed=$compressed negatives=12 repaints=72 outside=0 failures=0\r?$")) { throw 'Horizontal summary differs.' }
Write-Host "PASS: horizontal 144 fixtures, $groups groups, $compressed fitted, 12 overflow controls, 72 partial-row repaints and 12 bitmaps."
