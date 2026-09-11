[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath,[datetime]$Started=[datetime]::MinValue)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 3.0
$text=[IO.File]::ReadAllText($ReportPath)
$cases=[regex]::Matches($text,'(?ms)^PAINT_CASE: dip=(\d+) dpi=(\d+) canvas=(\d+),(\d+)\r?\n(.*?)^PAINT_CASE_END: fixtures=6\r?$')
if($cases.Count -ne 12){throw 'Paint matrix incomplete.'}
$names=@('Marked-pair','Joined-pair','Marked-word','Stacked-context','Long-joined','Fallback-marks')
$starts=@(0,1,0,0,1,0); $ends=@(2,2,2,3,2,2); $lengths=@(4,4,7,6,8,7)
$seen=@{}; $sourceChecks=0
foreach($case in $cases){
    $dip=[int]$case.Groups[1].Value; $dpi=[int]$case.Groups[2].Value; $key="$dip-$dpi"
    if($seen.ContainsKey($key) -or $dip -notin @(12,18,24) -or $dpi -notin @(96,120,144,192)){throw 'Invalid paint configuration.'}
    $seen[$key]=$true
    $width=[int]$case.Groups[3].Value; $height=[int]$case.Groups[4].Value
    if($width -ne 1000 -or $height -ne 48+6*(3*([int][Math]::Ceiling($dip*$dpi/96.0*1.8)+20)+32)){throw 'Paint canvas differs.'}
    $fixtures=[regex]::Matches($case.Groups[5].Value,'(?ms)^PAINT_FIXTURE: index=(\d+) name=([\w-]+) source=(\d+) columns=(\d+) grid=(\d+),(\d+) scale=([\d.eE+\-]+) scaleY=1\r?\n(.*?)^PAINT_RESULT: index=(\d+) references=6 uniform=2 droppedColor=2 stale=rejected repaints=4 outside=0 cycle=identical selection=spatial-review\r?$')
    if($fixtures.Count -ne 6){throw 'Paint fixture accounting differs.'}
    for($i=0;$i -lt 6;++$i){
        $f=$fixtures[$i]; $body=$f.Groups[8].Value; $length=[int]$f.Groups[3].Value; $columns=[int]$f.Groups[4].Value
        $scale=[double]::Parse($f.Groups[7].Value,[Globalization.CultureInfo]::InvariantCulture)
        if([int]$f.Groups[1].Value -ne $i -or [int]$f.Groups[9].Value -ne $i -or $f.Groups[2].Value -ne $names[$i] -or $length -ne $lengths[$i] -or $columns -lt 2 -or [int]$f.Groups[5].Value -le 0 -or [int]$f.Groups[6].Value -le 0 -or $scale -le 0 -or $scale -gt 1){throw 'Paint identity/geometry differs.'}
        $cells=[regex]::Matches($body,'(?m)^PAINT_CELL: text=(\d+),(\d+) visual=(\d+),(\d+)\r?$')
        $source=0; $column=$columns; $selected=$null
        foreach($cell in $cells){
            $a=[int]$cell.Groups[1].Value; $z=[int]$cell.Groups[2].Value; $l=[int]$cell.Groups[3].Value; $r=[int]$cell.Groups[4].Value
            if($a -ne $source -or $z -le $a -or $z -gt $length -or $r -ne $column -or $l -ge $r -or $l -lt 0){throw 'Paint source/column partition differs.'}
            if(1 -ge $a -and 1 -lt $z){$selected=@($a,$z,$l,$r)}
            $source=$z; $column=$l
        }
        if($source -ne $length -or $column -ne 0 -or $null -eq $selected){throw 'Paint ownership incomplete.'}
        if($selected[0] -ne $starts[$i] -or $selected[1] -ne $ends[$i]){throw 'Paint mark/base boundary differs.'}
        $marker="PAINT_SELECTION: query=1,2 snapped=$($selected[0]),$($selected[1]) visual=$($selected[2]),$($selected[3]) copy=logical-complete invalid=rejected"
        if($body -notmatch ('(?m)^'+[regex]::Escape($marker)+'\r?$')){throw 'Paint selection/copy check missing.'}
        $sourceChecks+=$length
    }
    $path="$ReportPath.bmp.paint-$dip-$dpi.bmp"; $file=Get-Item -LiteralPath $path
    if($file.Length -ne 54+4*$width*$height -or ($Started -ne [datetime]::MinValue -and $file.LastWriteTime -lt $Started.AddSeconds(-2))){throw 'Invalid/stale paint bitmap.'}
    $stream=[IO.File]::OpenRead($path)
    try{$header=[byte[]]::new(54); if($stream.Read($header,0,54) -ne 54){throw 'Short paint bitmap.'}}finally{$stream.Dispose()}
    if([Text.Encoding]::ASCII.GetString($header,0,2) -ne 'BM' -or [BitConverter]::ToInt32($header,10) -ne 54 -or [BitConverter]::ToInt32($header,18) -ne $width -or [BitConverter]::ToInt32($header,22) -ne -$height -or [BitConverter]::ToUInt16($header,28) -ne 32 -or [BitConverter]::ToInt32($header,30) -ne 0){throw 'Paint bitmap header differs.'}
}
if($text -notmatch "(?m)^PAINT_SUMMARY: cases=12 fixtures=72 sourceChecks=$sourceChecks references=432 uniform=144 droppedColor=144 stale=72 repaints=288 images=12 failures=0\r?$"){throw 'Paint summary differs.'}
Write-Host "PASS: paint 72 fixtures, $sourceChecks source round trips, 432 raster references, 144 uniform/paint controls, 72 stale checks, 288 partial repaints and 12 bitmaps."
