[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Get-VT7Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$executable = Join-Path $BinaryDirectory 'VT7.Host.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "Missing VT7 executable: $executable" }

$reportRoot = if ($OutputDirectory) {
    $parent = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $identity = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    Join-Path $parent ('session-outbound-' + $identity)
} else { Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\Session" }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$reportPath = Join-Path $reportRoot 'session-outbound.log'
$sumPath = Join-Path $BinaryDirectory 'SHA256SUMS.txt'
if (Test-Path -LiteralPath $sumPath -PathType Leaf) {
    foreach ($line in [IO.File]::ReadAllLines($sumPath)) {
        if (-not $line.Trim()) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Malformed package hash line: $line" }
        $file = Join-Path $BinaryDirectory $Matches[2].Replace('/', '\')
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Package file is missing: $($Matches[2])" }
        if ((Get-VT7Sha256 -Path $file) -ne $Matches[1]) { throw "Package hash mismatch: $($Matches[2])" }
    }
}
$environmentPath = Join-Path $reportRoot 'RUN-ENVIRONMENT.txt'
$environment = @(
    'CapturedUtc=' + [DateTime]::UtcNow.ToString('o')
    'OSVersion=' + [Environment]::OSVersion.VersionString
    'Is64BitOperatingSystem=' + [Environment]::Is64BitOperatingSystem
    'Is64BitProcess=' + [Environment]::Is64BitProcess
    'Culture=' + [Globalization.CultureInfo]::CurrentCulture.Name
    'UICulture=' + [Globalization.CultureInfo]::CurrentUICulture.Name
    'PowerShell=' + $PSVersionTable.PSVersion.ToString()
    'HostSHA256=' + (Get-VT7Sha256 -Path $executable)
    'NativeSHA256=' + (Get-VT7Sha256 -Path (Join-Path $BinaryDirectory 'VT7.Native.dll'))
)
[IO.File]::WriteAllLines($environmentPath, $environment, (New-Object Text.UTF8Encoding($false)))
$started = Get-Date
$arguments = @(
    '--session-outbound-test',
    '--renderer', 'atlas-d3d-hardware',
    '--diagnostics-output', ('"' + $reportPath + '"')
)

$process = Start-Process -FilePath $executable -ArgumentList $arguments -PassThru -WindowStyle Hidden
try {
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw 'VT7 session-outbound test exceeded its 60-second timeout.'
    }
    if ($process.ExitCode -ne 0) { throw "VT7 session-outbound test failed ($($process.ExitCode)). See $reportPath" }
}
finally {
    $process.Dispose()
}

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'VT7 session-outbound test did not produce a report.' }
$report = Get-Item -LiteralPath $reportPath
if ($report.LastWriteTime -lt $started.AddSeconds(-2)) { throw 'VT7 session-outbound test left a stale report.' }
$text = [IO.File]::ReadAllText($reportPath)
$required = @(
    'PASS: outbound queue rejects stale generations',
    'PASS: native HWND commits Croatian UTF-16 once',
    'keeps Ctrl+C and Ctrl+Break distinct without duplicate ETX',
    'encodes non-text keys through TerminalCore',
    'emits one authoritative resize grid'
)
foreach ($line in $required) {
    if (-not $text.Contains($line)) { throw "Session-outbound report is missing: $line" }
}
if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') {
    throw "VT7 session-outbound report did not pass. See $reportPath"
}
Write-Host "PASS: session-outbound foundation ($reportPath)"
if ($OutputDirectory) { Write-Host "Return this entire log folder: $reportRoot" }
