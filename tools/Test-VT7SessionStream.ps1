[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$executable = Join-Path $BinaryDirectory 'VT7.Host.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "Missing VT7 executable: $executable" }

$reportRoot = if ($OutputDirectory) {
    $parent = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $identity = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    Join-Path $parent ('session-ownership-' + $identity)
} else { Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\Session" }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$reportPath = Join-Path $reportRoot 'session-stream.log'
$started = Get-Date
$arguments = @(
    '--session-stream-test',
    '--renderer', 'atlas-d3d-hardware',
    '--diagnostics-output', $reportPath
)

$process = Start-Process -FilePath $executable -ArgumentList $arguments -PassThru -WindowStyle Hidden
try {
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw 'VT7 session-stream test exceeded its 60-second timeout.'
    }
    if ($process.ExitCode -ne 0) { throw "VT7 session-stream test failed ($($process.ExitCode)). See $reportPath" }
}
finally {
    $process.Dispose()
}

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'VT7 session-stream test did not produce a report.' }
$report = Get-Item -LiteralPath $reportPath
if ($report.LastWriteTime -lt $started.AddSeconds(-2)) { throw 'VT7 session-stream test left a stale report.' }
$text = [IO.File]::ReadAllText($reportPath)
$required = @(
    'PASS: Session UTF-8 and VT stream split at every byte boundary',
    'PASS: Session malformed and incomplete UTF-8 policy',
    'PASS: single-chunk stream',
    'PASS: byte-at-a-time UTF-8 and VT stream produced the exact baseline raster',
    'PASS: incomplete UTF-8 at EOF returned ERROR_NO_UNICODE_TRANSLATION',
    'recovered with irregular chunks and exact raster',
    'PASS: ABI 11 detached HWND',
    'PASS: TerminalSession switched fake root/overlay input generations 1/2/3',
    'PASS: session owner disposed the native surface with no surviving HWND'
)
foreach ($line in $required) {
    if (-not $text.Contains($line)) { throw "Session-stream report is missing: $line" }
}
if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') {
    throw "VT7 session-stream report did not pass. See $reportPath"
}
Write-Host "PASS: session-stream foundation ($reportPath)"
