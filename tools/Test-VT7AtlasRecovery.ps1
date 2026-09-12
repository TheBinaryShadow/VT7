[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\Recovery"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$cases = @(
    @{ Mode = 'atlas-auto'; Scenario = 'startup-hardware' },
    @{ Mode = 'atlas-auto'; Scenario = 'startup-both' },
    @{ Mode = 'atlas-d3d-hardware'; Scenario = 'startup-hardware' },
    @{ Mode = 'atlas-auto'; Scenario = 'present-permanent' },
    @{ Mode = 'atlas-d3d-warp'; Scenario = 'present-permanent' },
    @{ Mode = 'atlas-auto'; Scenario = 'close-retry' }
)
foreach ($mode in @('atlas-auto','atlas-d3d-hardware','atlas-d3d-warp','atlas-d2d-hardware','atlas-d2d-warp')) {
    foreach ($scenario in @('present-once','present-twice')) { $cases += @{ Mode = $mode; Scenario = $scenario } }
}
foreach ($case in $cases) {
    $name = $case.Mode + '-' + $case.Scenario
    $report = Join-Path $reportRoot ($name + '.log')
    $arguments = '--recovery-test ' + $case.Scenario + ' --renderer ' + $case.Mode + ' --diagnostics-output "' + $report + '"'
    $started = Get-Date
    $process = Start-Process -FilePath (Join-Path $BinaryDirectory 'VT7.Host.exe') -ArgumentList $arguments -PassThru -WindowStyle Hidden
    try {
        if (!$process.WaitForExit(45000)) { $process.Kill(); throw "Recovery test timed out: $name" }
        if (!(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $started.AddSeconds(-2)) { throw "Missing/stale report: $name" }
        $text = [IO.File]::ReadAllText($report)
        if ($process.ExitCode -ne 0 -or $text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:' -or
            $text -notmatch 'PASS: controlled recovery HWND disposed' -or $text -notmatch "Controlled recovery: $($case.Scenario),") { throw "Recovery test failed: $report" }
        $fatal = $case.Scenario -eq 'startup-both' -or $case.Scenario -eq 'present-permanent' -or ($case.Scenario -eq 'startup-hardware' -and $case.Mode -ne 'atlas-auto')
        if (!$fatal -and $case.Scenario -ne 'close-retry') {
            $png = $report + '.png'
            if ($text -notmatch 'PASS: recovered frame, correct backend and nonblank glyphs' -or
                !(Test-Path -LiteralPath $png) -or (Get-Item -LiteralPath $png).LastWriteTime -lt $started.AddSeconds(-2)) { throw "Recovery evidence incomplete: $name" }
        }
        Write-Host "PASS: $name ($report)"
    } finally { $process.Dispose() }
}
Write-Host 'PASS: 16 controlled recovery scenarios (injected errors, not real driver loss)'
