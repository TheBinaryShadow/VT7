[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath, [datetime]$Started = [datetime]::MinValue)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$text = [IO.File]::ReadAllText($ReportPath)
$freshAfter = if ($Started -eq [datetime]::MinValue) { $Started } else { $Started.AddSeconds(-2) }
$cases = [regex]::Matches($text, '(?ms)^ARABIC_CASE: dip=(\d+) dpi=(\d+) canvas=(\d+),(\d+)\r?\n(.*?)^ARABIC_CASE_END: fixtures=12 pages=2\r?$')
if ($cases.Count -ne 12) { throw 'Arabic size/DPI matrix incomplete.' }
$names = @('Plain','Marks','Mixed','Bold-boundary','Italic-boundary','Face-boundary','Same-style','Fallback-bold','Lam-alef-split','Join-controls','Arabic-digits','Latin-control')
$seen = @{}; $contexts = 0; $groups = 0
foreach ($case in $cases) {
    $dip = [int]$case.Groups[1].Value; $dpi = [int]$case.Groups[2].Value; $key = "$dip-$dpi"
    if ($seen.ContainsKey($key) -or $dip -notin @(12,18,24) -or $dpi -notin @(96,120,144,192)) { throw 'Unexpected/duplicate Arabic configuration.' }
    $seen[$key] = $true
    $fixtures = [regex]::Matches($case.Groups[5].Value, '(?ms)^ARABIC_FIXTURE: index=(\d+) name=([\w-]+) source=(\d+) cells=(\d+) runs=(\d+) groups=(\d+)\r?\n(.*?)^ARABIC_RESULT: index=(\d+) source=unchanged cells=unchanged projection=bijective\r?$')
    if ($fixtures.Count -ne 12) { throw 'Arabic fixture accounting differs.' }
    for ($i = 0; $i -lt 12; ++$i) {
        $fixture = $fixtures[$i]; $body = $fixture.Groups[7].Value
        if ([int]$fixture.Groups[1].Value -ne $i -or [int]$fixture.Groups[8].Value -ne $i -or $fixture.Groups[2].Value -ne $names[$i]) { throw 'Arabic fixture identity differs.' }
        $length = [int]$fixture.Groups[3].Value; $columns = [int]$fixture.Groups[4].Value
        if ($length -le 0 -or $columns -le 0 -or [int]$fixture.Groups[5].Value -le 0) { throw 'Empty Arabic fixture.' }
        if ($body -notmatch '(?m)^ARABIC_RASTER: immediate=identical shifted=different owners=destroyed\r?$') { throw 'Arabic retained/direct pixel comparison missing.' }
        if ($body -notmatch '(?m)^ARABIC_NATURAL: repaired visual-order proportional diagnostic-only\r?$') { throw 'Repaired proportional reference missing.' }
        $context = [regex]::Matches($body, '(?m)^ARABIC_CONTEXT: source=(\d+) glyphs=([1-9]\d*), wholeWord=identical isolated=(same|different) face=identical\r?$')
        $expected = if ($i -in @(3,4,5,6,7)) { 3 } else { 0 }
        if ($context.Count -ne $expected) { throw 'Arabic joining context or negative control missing.' }
        for ($c = 0; $c -lt $expected; ++$c) { if ([int]$context[$c].Groups[1].Value -ne $c) { throw 'Arabic joining source association differs.' } }
        if ($expected) {
            $changed = @($context | Where-Object { $_.Groups[3].Value -eq 'different' }).Count
            if ($changed -le 0 -or $body -notmatch "(?m)^ARABIC_NEGATIVE: isolatedWord=different changed=$changed\r?$") { throw 'Isolated-word negative not detected.' }
        }
        $contexts += $context.Count
        $signatures = @{}
        foreach ($mode in @('C','V')) {
            $records = [regex]::Matches($body, "(?m)^ARABIC_GROUP: mode=$mode text=(\d+),(\d+) logical=(\d+),(\d+) display=(\d+),(\d+) bidi=(\d+) glyphs=(\d+),(\d+)\r?$")
            if ($records.Count -ne [int]$fixture.Groups[6].Value) { throw 'Arabic group accounting differs.' }
            $sourceCoverage = [int[]]::new($length); $logicalCoverage = [int[]]::new($columns); $displayCoverage = [int[]]::new($columns)
            $signature = @()
            foreach ($record in $records) {
                $a = [int]$record.Groups[1].Value; $b = [int]$record.Groups[2].Value
                $l = [int]$record.Groups[3].Value; $r = [int]$record.Groups[4].Value
                $x = [int]$record.Groups[5].Value; $y = [int]$record.Groups[6].Value
                if ($b -le $a -or $b -gt $length -or $r -le $l -or $r -gt $columns -or $y -le $x -or $y -gt $columns -or ($r-$l) -ne ($y-$x) -or [int]$record.Groups[9].Value -le [int]$record.Groups[8].Value) { throw 'Arabic source/cell/glyph bounds invalid.' }
                if ($mode -eq 'C' -and ($l -ne $x -or $r -ne $y)) { throw 'Logical Arabic mode reordered core cells.' }
                for ($c=$a; $c -lt $b; ++$c) { ++$sourceCoverage[$c] }
                for ($c=$l; $c -lt $r; ++$c) { ++$logicalCoverage[$c] }
                for ($c=$x; $c -lt $y; ++$c) { ++$displayCoverage[$c] }
                $signature += "$a,$b,$l,$r,$($record.Groups[7].Value),$($record.Groups[8].Value),$($record.Groups[9].Value)"
            }
            foreach ($coverage in @($sourceCoverage,$logicalCoverage,$displayCoverage)) { if (@($coverage | Where-Object { $_ -ne 1 }).Count) { throw 'Arabic projection lost or duplicated source/cells.' } }
            $signatures[$mode] = ($signature | Sort-Object) -join ';'
            $groups += $records.Count
        }
        if ($signatures.C -ne $signatures.V) { throw 'Arabic visual projection altered glyph ownership.' }
        $legacy = if ($i -eq 5) { 'unavailable-family-input' } else { 'drawn' }
        if ($body -notmatch "(?m)^ARABIC_LEGACY: $legacy\r?$") { throw 'Legacy comparison missing or mislabeled.' }
    }
    for ($page = 0; $page -lt 2; ++$page) {
        $path = "$ReportPath.bmp.arabic-$key-$page.bmp"
        if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).LastWriteTime -lt $freshAfter) { throw "Missing/stale Arabic bitmap: $path" }
        $bytes = [IO.File]::ReadAllBytes($path); $width = [int]$case.Groups[3].Value; $height = [int]$case.Groups[4].Value
        if ($bytes.Length -ne 54+4*$width*$height -or [Text.Encoding]::ASCII.GetString($bytes,0,2) -ne 'BM' -or [BitConverter]::ToInt32($bytes,18) -ne $width -or [BitConverter]::ToInt32($bytes,22) -ne -$height) { throw 'Invalid Arabic comparison bitmap.' }
    }
}
if ($contexts -ne 180 -or $text -notmatch '(?m)^ARABIC_SUMMARY: cases=12 fixtures=144 context=180 isolatedNegatives=60 raster=144 rasterNegatives=144 pages=24 failures=0\r?$') { throw 'Arabic summary differs.' }
$repairs = [regex]::Matches($text,'(?m)^ARABIC_REPAIR: text=\d+,\d+ status=repaired face=identical context=whole-source\r?$').Count
$reviews = [regex]::Matches($text,'(?m)^ARABIC_REPAIR: text=\d+,\d+ status=REVIEW reason=face-or-cluster-boundary\r?$').Count
if ($repairs -lt 1 -or $text -notmatch "(?m)^ARABIC_REPAIRS: changed=$repairs review=$reviews\r?$") { throw 'Arabic repair accounting differs.' }
Write-Host "PASS: Arabic 144 fixtures, 180 context checks, 60 isolated-word controls, 144 exact natural replays/shift controls, $groups projected groups, $repairs repairs, $reviews explicit reviews and 24 bitmaps."
