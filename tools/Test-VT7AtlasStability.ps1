[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [switch]$Soak,
    [switch]$Lifecycle,
    [ValidateSet('both','atlas-d3d-hardware','atlas-d3d-warp')][string]$Renderer = 'both'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
if ($Soak -and $Lifecycle) { throw 'Choose either -Lifecycle or -Soak, not both.' }
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$profile = if ($Soak) { 'extended' } elseif ($Lifecycle) { 'lifecycle' } else { 'quick' }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\Stability-$profile"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$cases = @('atlas-d3d-hardware','atlas-d3d-warp')
if ($Renderer -ne 'both') { $cases = @($Renderer) }
if (!$Soak -and !$Lifecycle) { $cases += 'idle-negative' }
foreach ($case in $cases) {
    $negative = $case -eq 'idle-negative'
    $mode = if ($negative) { 'atlas-d3d-warp' } else { $case }
    $report = Join-Path $reportRoot ($case + '.log')
    $arguments = '--stability-test --renderer ' + $mode + ' --diagnostics-output "' + $report + '"'
    if ($Soak) { $arguments += ' --stability-soak' }
    if ($Lifecycle) { $arguments += ' --stability-lifecycle' }
    if ($negative) { $arguments += ' --inject-stability-failure' }
    $started = Get-Date
    $process = Start-Process -FilePath (Join-Path $BinaryDirectory 'VT7.Host.exe') -ArgumentList $arguments -PassThru -WindowStyle Hidden
    try {
        $limit = if ($Soak) { 3600 } elseif ($Lifecycle) { 900 } else { 300 }
        while (!$process.WaitForExit(1000)) {
            if (((Get-Date) - $started).TotalSeconds -gt $limit) {
                $process.Kill(); throw "Stability test timed out: $case. Retain $report.progress.log"
            }
        }
        if (!(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $started.AddSeconds(-2)) { throw "Missing/stale stability report: $case" }
        $text = [IO.File]::ReadAllText($report)
        if ($negative) {
            if ($process.ExitCode -ne 1 -or $text -notmatch '(?m)^Passed: False\r?$' -or !$text.Contains('Idle redraw/wake invariant failed.')) { throw "Idle negative not detected: $report" }
        } else {
            $cycles = if ($Soak -or $Lifecycle) { 100 } else { 8 }
            $markers = @('PASS: explicit synchronized-output end','PASS: split DECSET 2026 missing-end timeout',
                'PASS: parked one-shot timer wake','PASS: 64 parked wake generations','PASS: hidden output consumed',"PASS: $cycles create/destroy cycles",'PASS: stability profile completed')
            if ($Soak) { $markers += 'PASS: extended active/idle soak completed' }
            if ($process.ExitCode -ne 0 -or $text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') { throw "Stability test failed: $report" }
            foreach ($marker in $markers) { if (!$text.Contains($marker)) { throw "Missing stability evidence '$marker': $report" } }
        }
        Write-Host "PASS: $profile $case ($report)"
    } finally { $process.Dispose() }
}
Write-Host "PASS: stability $profile profile. Quick tests do not replace extended or Windows 7 acceptance."
