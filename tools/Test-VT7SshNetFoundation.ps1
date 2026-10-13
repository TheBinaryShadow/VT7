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
$binaryRoot = [IO.Path]::GetFullPath($BinaryDirectory)
$hostPath = Join-Path $binaryRoot 'VT7.Host.exe'
$nativePath = Join-Path $binaryRoot 'VT7.Native.dll'
$runtimeNames = @(
    'Renci.SshNet.dll', 'BouncyCastle.Cryptography.dll',
    'Microsoft.Bcl.AsyncInterfaces.dll', 'Microsoft.Bcl.Cryptography.dll',
    'Microsoft.Extensions.DependencyInjection.Abstractions.dll', 'Microsoft.Extensions.Logging.Abstractions.dll',
    'System.Buffers.dll', 'System.Formats.Asn1.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll',
    'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll'
)
foreach ($path in @($hostPath, $nativePath) + @($runtimeNames | ForEach-Object { Join-Path $binaryRoot $_ })) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing SSH.NET direct-profile runtime file: $path" }
}

$sumPath = Join-Path $binaryRoot 'SHA256SUMS.txt'
if (Test-Path -LiteralPath $sumPath -PathType Leaf) {
    foreach ($line in [IO.File]::ReadAllLines($sumPath)) {
        if (-not $line.Trim()) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Malformed package hash line: $line" }
        $file = Join-Path $binaryRoot $Matches[2].Replace('/', '\')
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Package file is missing: $($Matches[2])" }
        if ((Get-VT7Sha256 -Path $file) -ne $Matches[1]) { throw "Package hash mismatch: $($Matches[2])" }
    }
}

$reportRoot = if ($OutputDirectory) {
    $parent = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $identity = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    Join-Path $parent ('sshnet-foundation-' + $identity)
} else { Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\SshNetFoundation" }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$reportPath = Join-Path $reportRoot 'sshnet-foundation.log'
$environmentPath = Join-Path $reportRoot 'RUN-ENVIRONMENT.txt'
$started = Get-Date

$environment = @(
    'CapturedUtc=' + [DateTime]::UtcNow.ToString('o')
    'OSVersion=' + [Environment]::OSVersion.VersionString
    'Is64BitOperatingSystem=' + [Environment]::Is64BitOperatingSystem
    'Is64BitProcess=' + [Environment]::Is64BitProcess
    'Culture=' + [Globalization.CultureInfo]::CurrentCulture.Name
    'UICulture=' + [Globalization.CultureInfo]::CurrentUICulture.Name
    'PowerShell=' + $PSVersionTable.PSVersion.ToString()
    'HostSHA256=' + (Get-VT7Sha256 -Path $hostPath)
    'NativeSHA256=' + (Get-VT7Sha256 -Path $nativePath)
    'SshNetSHA256=' + (Get-VT7Sha256 -Path (Join-Path $binaryRoot 'Renci.SshNet.dll'))
)
[IO.File]::WriteAllLines($environmentPath, $environment, (New-Object Text.UTF8Encoding($false)))

$arguments = @('--sshnet-foundation-test', '--renderer', 'atlas-d3d-hardware', '--diagnostics-output', $reportPath)
$process = Start-Process -FilePath $hostPath -ArgumentList $arguments -PassThru -WindowStyle Hidden
try {
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw 'VT7 SSH.NET foundation test exceeded its 60-second timeout.'
    }
    if ($process.ExitCode -ne 0) { throw "VT7 SSH.NET foundation test failed ($($process.ExitCode)). See $reportPath" }
}
finally { $process.Dispose() }

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'VT7 SSH.NET foundation test did not produce a report.' }
$report = Get-Item -LiteralPath $reportPath
if ($report.LastWriteTime -lt $started.AddSeconds(-2)) { throw 'VT7 SSH.NET foundation test left a stale report.' }
$text = [IO.File]::ReadAllText($reportPath)
$required = @(
    'Build: VT7 0.12.3',
    'Native: ABI 11, expected 11',
    'PASS: exact SSH.NET 2026.0.1-prerelease.6 f099365 and its twelve-file net48 runtime closure loaded.',
    'PASS: structured SSH options accept an absent known-host fallback and reject malformed SHA256 fingerprints.',
    'PASS: typed -4/-6 address-family constraints remain structured transport input.',
    'PASS: every SSH connection-dialog label and the selected authentication item have explicit WCAG AA contrast.',
    'PASS: the generation-bound host-trust dialog exposes cancel, connect-once and durable-trust actions with WCAG AA text contrast.',
    'PASS: direct-root session startup and serialized resize preserve authoritative cell and pixel dimensions.',
    'PASS: SshNetTransport owns and closes its structured authentication material without starting a connection.',
    'Error: None'
)
foreach ($line in $required) {
    if (-not $text.Contains($line)) { throw "SSH.NET foundation report is missing: $line" }
}
if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') {
    throw "VT7 SSH.NET foundation report did not pass. See $reportPath"
}
Write-Host "PASS: SSH.NET direct-profile foundation ($reportPath)"
if ($OutputDirectory) { Write-Host "Return this entire log folder: $reportRoot" }
