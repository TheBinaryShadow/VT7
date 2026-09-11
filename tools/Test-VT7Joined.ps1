[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath, [datetime]$Started = [datetime]::MinValue)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$text = [IO.File]::ReadAllText($ReportPath)
$freshAfter = if ($Started -eq [datetime]::MinValue) { $Started } else { $Started.AddSeconds(-2) }
$culture = [Globalization.CultureInfo]::InvariantCulture
$cases = [regex]::Matches($text,'(?ms)^JOINED_CASE: dip=(\d+) dpi=(\d+) canvas=(\d+),(\d+)\r?\n(.*?)^JOINED_CASE_END: fixtures=10 repaints=6\r?$')
if ($cases.Count -ne 12) { throw 'Joined matrix incomplete.' }
$names = @('Plain','Marks','Bold-boundary','Italic-boundary','Face-boundary','Fallback-bold','Lam-alef-split','Join-controls','Wide-nonjoining','Long-joined')
$seen=@{}; $compressed=0; $reviews=0
foreach ($case in $cases) {
    $dip=[int]$case.Groups[1].Value; $dpi=[int]$case.Groups[2].Value; $key="$dip-$dpi"
    if ($seen.ContainsKey($key) -or $dip -notin @(12,18,24) -or $dpi -notin @(96,120,144,192)) { throw 'Invalid joined configuration.' }
    $seen[$key]=$true
    $fixtures=[regex]::Matches($case.Groups[5].Value,'(?ms)^JOINED_FIXTURE: index=(\d+) name=([\w-]+)\r?\n(.*?)^JOINED_RESULT: index=(\d+) source=unchanged ownership=complete boundary=(REVIEW|preserved)\r?$')
    if ($fixtures.Count -ne 10) { throw 'Joined fixture accounting differs.' }
    for ($i=0; $i -lt 10; ++$i) {
        $fixture=$fixtures[$i]; $body=$fixture.Groups[3].Value
        if ([int]$fixture.Groups[1].Value -ne $i -or [int]$fixture.Groups[4].Value -ne $i -or $fixture.Groups[2].Value -ne $names[$i]) { throw 'Joined fixture identity differs.' }
        $prepare=[regex]::Match($body,'(?m)^JOINED_PREPARE: repaired=(\d+) reviews=(\d+) policy=(retain-original-boundary|context-preserved)\r?$')
        if (-not $prepare.Success) { throw 'Missing joined boundary policy.' }
        $review=[int]$prepare.Groups[2].Value; $reviews+=$review
        if (($review -gt 0) -ne ($fixture.Groups[5].Value -eq 'REVIEW') -or ($review -gt 0) -ne ($prepare.Groups[3].Value -eq 'retain-original-boundary')) { throw 'Joined boundary review hidden.' }
        $span=[regex]::Match($body,'(?m)^JOINED_SPAN: source=(\d+) columns=(\d+) grid=(\d+),(\d+) allocation=(\d+) scale=([\d.eE+\-]+) offset=([\d.eE+\-]+) scaleY=1 retries=(\d+) ink=(-?\d+),(-?\d+),(-?\d+),(-?\d+)\r?$')
        if (-not $span.Success) { throw 'Joined shared transform missing.' }
        $length=[int]$span.Groups[1].Value; $columns=[int]$span.Groups[2].Value; $width=[int]$span.Groups[3].Value; $height=[int]$span.Groups[4].Value
        $allocation=[int]$span.Groups[5].Value; $scale=[double]::Parse($span.Groups[6].Value,$culture); $offset=[double]::Parse($span.Groups[7].Value,$culture)
        $l=[int]$span.Groups[9].Value; $t=[int]$span.Groups[10].Value; $r=[int]$span.Groups[11].Value; $b=[int]$span.Groups[12].Value
        if ($length -lt 3 -or $columns -lt 3 -or $width -le 0 -or $height -le 0 -or $allocation -ne ($columns-2)*$width -or $scale -le 0 -or $scale -gt 1 -or [double]::IsNaN($offset) -or [double]::IsInfinity($offset) -or [int]$span.Groups[8].Value -gt 16 -or $l -lt 0 -or $r -gt $allocation -or $r -le $l -or $b -le $t) { throw 'Invalid joined fit or allocation.' }
        if ($scale -lt 1) { ++$compressed }
        foreach ($kind in @('CELL','OWNER')) {
            $records=[regex]::Matches($body,"(?m)^JOINED_${kind}: text=(\d+),(\d+) cells=(\d+),(\d+)\r?$")
            if (-not $records.Count) { throw 'Missing joined source ownership.' }
            $start = if ($kind -eq 'CELL') { 0 } else { 1 }
            $endText = if ($kind -eq 'CELL') { $length } else { $length-1 }
            $endCell = if ($kind -eq 'CELL') { $columns } else { $columns-1 }
            $sources=[int[]]::new($length); $cells=[int[]]::new($columns)
            foreach ($record in $records) {
                $a=[int]$record.Groups[1].Value; $z=[int]$record.Groups[2].Value; $c=[int]$record.Groups[3].Value; $d=[int]$record.Groups[4].Value
                if ($a -lt $start -or $z -le $a -or $z -gt $endText -or $c -lt $start -or $d -le $c -or $d -gt $endCell) { throw 'Joined owner range invalid.' }
                for ($j=$a; $j -lt $z; ++$j) { ++$sources[$j] }
                for ($j=$c; $j -lt $d; ++$j) { ++$cells[$j] }
            }
            for ($j=$start; $j -lt $endText; ++$j) { if ($sources[$j] -ne 1) { throw 'Joined source lost or duplicated.' } }
            for ($j=$start; $j -lt $endCell; ++$j) { if ($cells[$j] -ne 1) { throw 'Joined core cells lost or duplicated.' } }
        }
        if ($body -notmatch '(?m)^JOINED_CHECK: reference=identical displaced=different outside=0 visible=[1-9]\d* stale=rejected\r?$' -or $body -notmatch '(?m)^JOINED_PRESENT: outside=0\r?$') { throw 'Joined raster/safety controls missing.' }
        if ($i -eq 8 -and ($body -notmatch '(?m)^JOINED_OVERFLOW: unfittedOutside=[1-9]\d*\r?$' -or $scale -ge 1)) { throw 'Unfitted wide-span control missing.' }
    }
    $repaints=[regex]::Matches($case.Groups[5].Value,'(?m)^JOINED_REPAINT: step=(\d+) damage=(\d+),(\d+),(\d+),(\d+) mismatches=0 outside=0\r?$')
    if ($repaints.Count -ne 6) { throw 'Joined partial repaint matrix incomplete.' }
    for ($i=0; $i -lt 6; ++$i) {
        $record=$repaints[$i]; $l=[int]$record.Groups[2].Value; $t=[int]$record.Groups[3].Value; $r=[int]$record.Groups[4].Value; $b=[int]$record.Groups[5].Value
        if ([int]$record.Groups[1].Value -ne $i+1 -or $r -le $l -or $b -le $t -or $r -gt 1024 -or $b -gt 384 -or ($r-$l)*($b-$t) -ge 1024*384) { throw 'Invalid joined partial damage.' }
    }
    $path="$ReportPath.bmp.joined-$key.bmp"
    if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).LastWriteTime -lt $freshAfter) { throw 'Missing/stale joined bitmap.' }
    $bytes=[IO.File]::ReadAllBytes($path); $w=[int]$case.Groups[3].Value; $h=[int]$case.Groups[4].Value
    if ($bytes.Length -ne 54+4*$w*$h -or [Text.Encoding]::ASCII.GetString($bytes,0,2) -ne 'BM' -or [BitConverter]::ToInt32($bytes,18) -ne $w -or [BitConverter]::ToInt32($bytes,22) -ne -$h) { throw 'Invalid joined bitmap dimensions.' }
}
if ($compressed -lt 12 -or $text -notmatch "(?m)^JOINED_SUMMARY: cases=12 fixtures=120 compressed=$compressed reviews=$reviews references=120 spacingNegatives=120 overflowNegatives=12 stale=120 repaints=72 failures=0\r?$") { throw 'Joined summary differs.' }
Write-Host "PASS: joined 120 fixtures/references/spacing controls/stale checks, $compressed compressed, $reviews reviews, 12 overflow controls, 72 partial repaints and 12 bitmaps."
