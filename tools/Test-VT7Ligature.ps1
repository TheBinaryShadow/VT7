[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath, [datetime]$Started = [datetime]::MinValue)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$text = [IO.File]::ReadAllText($ReportPath)
$culture = [Globalization.CultureInfo]::InvariantCulture
$freshAfter = if ($Started -eq [datetime]::MinValue) { $Started } else { $Started.AddSeconds(-2) }
$cases = [regex]::Matches($text,'(?ms)^LIGATURE_CASE: dip=(\d+) dpi=(\d+) canvas=(\d+),(\d+)\r?\n(.*?)^LIGATURE_CASE_END: fixtures=8\r?$')
if ($cases.Count -ne 12) { throw 'Ligature matrix incomplete.' }
$names = @('Paint-only','Alef-bold','Lam-bold','Alef-italic','Alef-family','Fallback-bold','Hamza-bold','Madda-bold')
$seen = @{}
$sharedClusters=0
foreach ($case in $cases) {
    $dip=[int]$case.Groups[1].Value; $dpi=[int]$case.Groups[2].Value; $key="$dip-$dpi"
    if ($seen.ContainsKey($key) -or $dip -notin @(12,18,24) -or $dpi -notin @(96,120,144,192)) { throw 'Invalid ligature configuration.' }
    $seen[$key]=$true
    $width=[int]$case.Groups[3].Value; $height=[int]$case.Groups[4].Value
    $expectedHeight=48+4*(5*([int][Math]::Ceiling($dip*$dpi/96.0*1.8)+20)+32)
    if ($width -ne 1100 -or $height -ne $expectedHeight) { throw 'Ligature canvas differs.' }
    $fixtures=[regex]::Matches($case.Groups[5].Value,'(?ms)^LIGATURE_FIXTURE: index=(\d+) name=([\w-]+)\r?\n(.*?)^LIGATURE_RESULT: index=(\d+) source=unchanged regions=spatial-not-character-owned policy=(paint-only|REVIEW) panelGuards=5\r?$')
    if ($fixtures.Count -ne 8) { throw 'Ligature fixture accounting differs.' }
    for ($i=0; $i -lt 8; ++$i) {
        $fixture=$fixtures[$i]; $body=$fixture.Groups[3].Value
        if ([int]$fixture.Groups[1].Value -ne $i -or [int]$fixture.Groups[4].Value -ne $i -or $fixture.Groups[2].Value -ne $names[$i]) { throw 'Ligature fixture identity differs.' }
        $policy=if ($i -eq 0) {'paint-only'} else {'REVIEW'}
        if ($fixture.Groups[5].Value -ne $policy) { throw 'Ligature outline review hidden.' }
        $alef=if ($i -eq 6) {1571} elseif ($i -eq 7) {1570} else {1575}
        $same=if ($i -eq 0) {1} else {0}
        $source=[regex]::Match($body,"(?m)^LIGATURE_SOURCE: scalars=1604,$alef cells=2 sharedLam=([01]) sharedAlef=([01]) exactFaces=1 sameFace=$same\r?$")
        if (-not $source.Success) { throw 'Ligature source/face/shared-cluster record differs.' }
        $shared=[int]$source.Groups[1].Value+[int]$source.Groups[2].Value
        if ($i -ne 5 -and $shared -ne 2) { throw 'Explicit-font ligature shared cluster missing.' }
        $sharedClusters+=$shared
        $fit=[regex]::Match($body,'(?m)^LIGATURE_FIT: grid=(\d+),(\d+) scale=([\d.eE+\-]+) scaleY=1 lamInk=(-?\d+),(-?\d+),(-?\d+),(-?\d+) alefInk=(-?\d+),(-?\d+),(-?\d+),(-?\d+)\r?$')
        if (-not $fit.Success) { throw 'Ligature fit missing.' }
        $w=[int]$fit.Groups[1].Value; $h=[int]$fit.Groups[2].Value
        $scale=[double]::Parse($fit.Groups[3].Value,$culture)
        if ($w -le 0 -or $h -le 0 -or $scale -le 0 -or $scale -gt 1 -or [double]::IsNaN($scale)) { throw 'Invalid ligature scale/grid.' }
        foreach ($start in @(4,8)) {
            $l=[int]$fit.Groups[$start].Value; $t=[int]$fit.Groups[$start+1].Value
            $r=[int]$fit.Groups[$start+2].Value; $b=[int]$fit.Groups[$start+3].Value
            if ($l -lt 0 -or $r -gt 2*$w -or $r -le $l -or $b -le $t) { throw 'Ligature ink escapes allocation.' }
        }
        if ($body -notmatch '(?m)^LIGATURE_CHECK: references=4 droppedColor=2 outside=0 bothRegions=visible stale=rejected\r?$') { throw 'Ligature raster/safety checks missing.' }
    }
    foreach ($page in @(0,1)) {
        $path="$ReportPath.bmp.ligature-$dip-$dpi-$page.bmp"
        $file=Get-Item -LiteralPath $path
        if ($file.LastWriteTime -lt $freshAfter -or $file.Length -ne 54+4*$width*$height) { throw "Stale or invalid ligature bitmap: $path" }
        $stream=[IO.File]::OpenRead($path)
        try { $header=[byte[]]::new(54); if ($stream.Read($header,0,54) -ne 54) { throw 'Short ligature bitmap.' } } finally { $stream.Dispose() }
        if ([Text.Encoding]::ASCII.GetString($header,0,2) -ne 'BM' -or [BitConverter]::ToInt32($header,10) -ne 54 -or
            [BitConverter]::ToInt32($header,18) -ne $width -or [BitConverter]::ToInt32($header,22) -ne -$height -or
            [BitConverter]::ToUInt16($header,28) -ne 32 -or [BitConverter]::ToInt32($header,30) -ne 0) { throw 'Ligature bitmap format differs.' }
    }
}
if ($text -notmatch "(?m)^LIGATURE_SUMMARY: cases=12 fixtures=96 sharedClusters=$sharedClusters references=384 droppedColor=192 stale=96 reviews=84 images=24 failures=0\r?$") { throw 'Ligature summary differs.' }
Write-Host "PASS: ligature 96 fixtures, $sharedClusters whole-source shared clusters, 384 raster references, 192 dropped-color controls, 96 stale checks, 84 explicit reviews and 24 bitmaps."
