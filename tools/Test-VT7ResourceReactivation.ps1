[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BinaryDirectory,
    [ValidateSet('full','work-negative','idle-negative')][string]$Case = 'full'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$binary = [IO.Path]::GetFullPath($BinaryDirectory)
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$run = Join-Path $repositoryRoot ('artifacts/vt7/diagnostics/reactivation-test-' + $Case + '-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run | Out-Null
$report = Join-Path $run 'reactivation.log'
$arguments = '--resource-reactivation --diagnostics-output "' + $report + '"'
if ($Case -eq 'work-negative') { $arguments += ' --inject-workload-failure' }
if ($Case -eq 'idle-negative') { $arguments += ' --inject-stability-failure' }
$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = Join-Path $binary 'VT7.ResourceReactivation.exe'
$start.Arguments = $arguments; $start.WorkingDirectory = $binary
$start.UseShellExecute = $false; $start.CreateNoWindow = $true; $start.WindowStyle = 'Hidden'
$process = New-Object Diagnostics.Process
$process.StartInfo = $start
$utf8 = New-Object Text.UTF8Encoding($false)
try {
    if (!$process.Start()) { throw 'Could not start diagnostic.' }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $metadata = [ordered]@{ Case = $Case; PID = $process.Id; StartedUtc = $process.StartTime.ToUniversalTime().ToString('o');
        BinaryDirectory = $binary; ExecutableSHA256 = (Get-FileHash -LiteralPath $start.FileName).Hash;
        NativeSHA256 = (Get-FileHash -LiteralPath (Join-Path $binary 'VT7.Native.dll')).Hash; Arguments = $arguments }
    [IO.File]::WriteAllText((Join-Path $run 'RUN-INPUTS.json'), ($metadata | ConvertTo-Json), $utf8)
    Write-Host "Running $Case, PID $($process.Id), report: $report"
    $limit = if ($Case -eq 'full') { 2400 } else { 120 }
    while (!$process.WaitForExit(1000)) {
        if ($clock.Elapsed.TotalSeconds -gt $limit) { $process.Kill(); $process.WaitForExit(); throw "Timeout; partial evidence retained at $run" }
    }
    $metadata.ExitCode = $process.ExitCode; $metadata.ElapsedSeconds = $clock.Elapsed.TotalSeconds
    $text = [IO.File]::ReadAllText($report)
    if ($Case -eq 'full') {
        if ($process.ExitCode -notin @(0,3) -or $text -notmatch '(?m)^COLLECTION=COMPLETE ') { throw "Collection incomplete: $report" }
        $metadata.Collection = 'Complete; independent report validation is required.'
    } else {
        $expected = if ($Case -eq 'work-negative') { 'Injected workload failure before first measured lifecycle.' } else { 'Idle redraw/wake invariant failed.' }
        if ($process.ExitCode -ne 1 -or !$text.Contains($expected) -or !$text.Contains('COLLECTION=INCOMPLETE') -or $text.Contains('COLLECTION=COMPLETE')) {
            throw "Expected negative was not detected: $report"
        }
        $metadata.Collection = 'Expected failure detected.'
    }
    $metadata.ReportSHA256 = (Get-FileHash -LiteralPath $report).Hash
    [IO.File]::WriteAllText((Join-Path $run 'RUN-RESULT.json'), ($metadata | ConvertTo-Json), $utf8)
    Write-Host "$($metadata.Collection) Exit $($process.ExitCode); $run"
} finally {
    if ($process.Id -and !$process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose()
}
