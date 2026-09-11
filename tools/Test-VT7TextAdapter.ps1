[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath, [datetime]$Started = [datetime]::MinValue)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$text = [IO.File]::ReadAllText($ReportPath)
$freshAfter = if ($Started -eq [datetime]::MinValue) { $Started } else { $Started.AddSeconds(-2) }
$cases = [regex]::Matches($text, '(?ms)^ADAPTER_CASE: dip=(\d+) dpi=(\d+) grid=(\d+),(\d+) baseline=(\d+) em=([\d.]+) canvas=(\d+),(\d+)\r?\n(.*?)^ADAPTER_CASE_END: fixtures=16\r?$')
if ($cases.Count -ne 12) { throw 'Adapter size/DPI matrix incomplete.' }
$seen = @{}
$groups = 0
$names = @('Latin','CJK','Supplementary','Arabic','Arabic-mixed','Arabic-marks','Indic','Emoji-sequence',
    'Bold-italic-split','Arabic-style-split','Arabic-equal-style','Stacked-marks','Private-BMP','Private-SMP','Hebrew-mixed','Missing-scalar')
$sourceCells = @{}
foreach ($case in $cases) {
    $dip = [int]$case.Groups[1].Value; $dpi = [int]$case.Groups[2].Value
    $key = "$dip-$dpi"
    if ($seen.ContainsKey($key) -or $dip -notin @(12,18,24) -or $dpi -notin @(96,120,144,192)) { throw 'Invalid adapter configuration.' }
    $seen[$key] = $true
    $width = [int]$case.Groups[3].Value; $height = [int]$case.Groups[4].Value; $baseline = [int]$case.Groups[5].Value
    $em = [double]::Parse($case.Groups[6].Value,[Globalization.CultureInfo]::InvariantCulture)
    if ($width -lt 1 -or $height -lt 1 -or $baseline -lt 0 -or $baseline -gt $height -or $em -ne $dip*$dpi/96) { throw 'Invalid adapter metrics.' }
    $fixtures = [regex]::Matches($case.Groups[9].Value,'(?ms)^ADAPTER_FIXTURE: index=(\d+) name=([^\r\n ]+) source=(\d+) cells=(\d+) runs=(\d+) mapUs=[\d.eE+\-]+\r?\n(.*?)^ADAPTER_RESULT: index=(\d+) mapping=PASS lifetime=PASS freshPixels=PASS stale=7 ordering=core-logical\r?$')
    if ($fixtures.Count -ne 16) { throw 'Adapter fixture set incomplete.' }
    for ($i=0; $i -lt 16; ++$i) {
        $fixture = $fixtures[$i]
        if ([int]$fixture.Groups[1].Value -ne $i -or [int]$fixture.Groups[7].Value -ne $i -or $fixture.Groups[2].Value -ne $names[$i]) { throw 'Adapter fixture order/identity changed.' }
        $body = $fixture.Groups[6].Value
        $cells = [regex]::Matches($body,'(?m)^ADAPTER_CELL: text=(\d+),(\d+) cells=(\d+),(\d+)\r?$')
        $source = 0; $column = 0; $boundaries = @{}
        foreach ($cell in $cells) {
            $a=[int]$cell.Groups[1].Value; $b=[int]$cell.Groups[2].Value
            $c=[int]$cell.Groups[3].Value; $d=[int]$cell.Groups[4].Value
            if ($a -ne $source -or $b -le $a -or $c -ne $column -or $d -le $c) { throw 'Adapter core span discontinuity.' }
            $boundaries[$a]=$c; $boundaries[$b]=$d; $source=$b; $column=$d
        }
        if ($source -ne [int]$fixture.Groups[3].Value -or $column -ne [int]$fixture.Groups[4].Value) { throw 'Adapter source/cell accounting differs.' }
        $signature = ($cells | ForEach-Object { $_.Value.Trim() }) -join ';'
        if ($sourceCells.ContainsKey($i) -and $sourceCells[$i] -ne $signature) { throw 'Adapter core cells changed with size/DPI.' }
        $sourceCells[$i] = $signature
        $runs = [regex]::Matches($body,'(?ms)^ADAPTER_RUN: text=(\d+),(\d+) glyphs=(\d+) layoutBidi=(\d+) drawBidi=0 em=([\d.]+) private=([01]) missing=(\d+)\r?\n(.*?)(?=^ADAPTER_RUN:|^ADAPTER_INK:|\z)')
        if ($runs.Count -ne [int]$fixture.Groups[5].Value) { throw 'Adapter run accounting differs.' }
        $source = 0; $column = 0
        foreach ($run in $runs) {
            if ([int]$run.Groups[1].Value -ne $source) { throw 'Adapter runs are not in logical source order.' }
            $glyph = 0
            $maps = [regex]::Matches($run.Groups[8].Value,'(?m)^ADAPTER_GROUP: text=(\d+),(\d+) cells=(\d+),(\d+) glyphs=(\d+),(\d+) x=(\d+) width=(\d+) advance=([\d.\-]+)\r?$')
            foreach ($map in $maps) {
                $a=[int]$map.Groups[1].Value; $b=[int]$map.Groups[2].Value
                $c=[int]$map.Groups[3].Value; $d=[int]$map.Groups[4].Value
                $g=[int]$map.Groups[5].Value; $h=[int]$map.Groups[6].Value
                $advance=[double]::Parse($map.Groups[9].Value,[Globalization.CultureInfo]::InvariantCulture)
                if ($a -ne $source -or $b -le $a -or $c -ne $column -or $d -le $c -or $g -ne $glyph -or $h -le $g -or
                    -not $boundaries.ContainsKey($a) -or -not $boundaries.ContainsKey($b) -or $boundaries[$a] -ne $c -or $boundaries[$b] -ne $d -or
                    [int]$map.Groups[7].Value -ne $c*$width -or [int]$map.Groups[8].Value -ne ($d-$c)*$width -or
                    [math]::Abs($advance-($d-$c)*$width) -gt .001) { throw 'Invalid adapter source/glyph/cell/pixel mapping.' }
                $source=$b; $column=$d; $glyph=$h; ++$groups
            }
            if ($source -ne [int]$run.Groups[2].Value -or $glyph -ne [int]$run.Groups[3].Value) { throw 'Incomplete adapter glyph coverage.' }
            if ($i -in @(12,13) -and ($run.Groups[6].Value -ne '1' -or $run.Groups[7].Value -ne '0')) { throw 'Private adapter mapping missing.' }
        }
        if ($source -ne [int]$fixture.Groups[3].Value -or $column -ne [int]$fixture.Groups[4].Value) { throw 'Incomplete adapter logical coverage.' }
        if ($i -in @(3,4,5,9,10,14) -and $body -notmatch 'layoutBidi=[13579]') { throw 'RTL comparison is missing.' }
    }
    $path = $ReportPath + ".bmp.adapter-$key.bmp"
    if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).LastWriteTime -lt $freshAfter) { throw "Missing/stale adapter bitmap $key" }
    $bytes=[IO.File]::ReadAllBytes($path)
    $canvasWidth=[int]$case.Groups[7].Value; $canvasHeight=[int]$case.Groups[8].Value
    if ($bytes.Length -ne 54+4*$canvasWidth*$canvasHeight -or [Text.Encoding]::ASCII.GetString($bytes,0,2) -ne 'BM' -or
        [BitConverter]::ToInt32($bytes,18) -ne $canvasWidth -or [BitConverter]::ToInt32($bytes,22) -ne -$canvasHeight) { throw 'Invalid adapter bitmap.' }
}
$negativeNames=@('incomplete-cells','cell-gap','style-bisects-core','split-surrogate','unpaired-surrogate','invalid-metrics','control-character','missing-primary')
foreach ($name in $negativeNames) {
    if ([regex]::Matches($text,('(?m)^ADAPTER_NEGATIVE: '+[regex]::Escape($name)+' rejected\r?$')).Count -ne 1) { throw "Missing adapter negative: $name" }
}
if ($text -notmatch ('(?m)^ADAPTER_SUMMARY: cases=12 fixtures=192 groups='+$groups+' stale=1344 negatives=8 failures=0\r?$')) { throw 'Adapter summary mismatch.' }
Write-Host "PASS: adapter 12 configurations, 192 logical mappings, $groups glyph groups, 1344 stale-key checks, 8 invalid-input controls and 12 bitmaps."
