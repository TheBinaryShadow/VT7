[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [string]$OutputDirectory,
    [string]$ExpectedSshKeygenFileVersion
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

function Find-SshKeygen {
    $candidates = New-Object Collections.Generic.List[string]
    foreach ($root in @($env:ProgramW6432, $env:ProgramFiles)) {
        if ($root) { $candidates.Add((Join-Path $root 'OpenSSH\ssh-keygen.exe')) }
    }
    if ($env:SystemRoot) { $candidates.Add((Join-Path $env:SystemRoot 'System32\OpenSSH\ssh-keygen.exe')) }
    $command = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates.Add($command.Source) }
    return @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -Unique)[0]
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$binaryRoot = [IO.Path]::GetFullPath($BinaryDirectory)
$hostPath = Join-Path $binaryRoot 'VT7.Host.exe'
$nativePath = Join-Path $binaryRoot 'VT7.Native.dll'
foreach ($path in @($hostPath, $nativePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing KH01 runtime file: $path" }
}
$sshKeygen = Find-SshKeygen
if (-not $sshKeygen) { throw 'ssh-keygen.exe was not found for the KH01 differential oracle.' }

$reportRoot = if ($OutputDirectory) {
    $parent = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $identity = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    Join-Path $parent ('known-hosts-kh01-' + $identity)
} else { Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\KnownHosts" }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$reportPath = Join-Path $reportRoot 'known-hosts.log'
$environmentPath = Join-Path $reportRoot 'RUN-ENVIRONMENT.txt'
$started = Get-Date
$sshKeygenInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($sshKeygen)
if ($ExpectedSshKeygenFileVersion -and $sshKeygenInfo.FileVersion -ne $ExpectedSshKeygenFileVersion) {
    throw "Expected ssh-keygen.exe file version $ExpectedSshKeygenFileVersion, found $($sshKeygenInfo.FileVersion) at $sshKeygen."
}
$sshKeygenHash = Get-VT7Sha256 -Path $sshKeygen

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
    'SshKeygenFileVersion=' + $sshKeygenInfo.FileVersion
    'SshKeygenSHA256=' + $sshKeygenHash
)
[IO.File]::WriteAllLines($environmentPath, $environment, (New-Object Text.UTF8Encoding($false)))

$arguments = @('--known-hosts-test', '--renderer', 'atlas-d3d-hardware', '--diagnostics-output', $reportPath)
$process = Start-Process -FilePath $hostPath -ArgumentList $arguments -PassThru -WindowStyle Hidden
try {
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw 'VT7 KH01 test exceeded its 60-second timeout.'
    }
    if ($process.ExitCode -ne 0) { throw "VT7 KH01 test failed ($($process.ExitCode)). See $reportPath" }
}
finally { $process.Dispose() }

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'VT7 KH01 test did not produce a report.' }
$report = Get-Item -LiteralPath $reportPath
if ($report.LastWriteTime -lt $started.AddSeconds(-2)) { throw 'VT7 KH01 test left a stale report.' }
$text = [IO.File]::ReadAllText($reportPath)
$required = @(
    'Build: VT7 0.11.0'
    'Native: ABI 11, expected 11'
    'PASS: OpenSSH host tokens preserve default-port identity and bracket every non-default port.'
    'PASS: presented host keys use the exact RFC 4253 blob type, RSA key identity and canonical SHA256 fingerprint.'
    'PASS: bounded known-host parsing accepts comments, markers, patterns, hashes and byte-preserved lines.'
    'PASS: literal, wildcard, negated and OpenSSH |1| hashed host matching passed.'
    'PASS: raw-key trust resolves matching, unknown, changed, revoked, unreadable and certificate-policy states.'
    'PASS: four-source OpenSSH loading is immutable, bounded and fail-closed for missing, changed, revoked and unreadable stores.'
    'PASS: stored matches need no fingerprint, unknown hosts require a generation-bound prompt pin and explicit fingerprint mismatches remain blocked.'
    'PASS: durable first-contact writes preserve existing bytes, reject stale decisions, serialize writers and verify read-back.'
    'PASS: deterministic hash properties and 1024 bounded arbitrary-byte parser cases passed.'
    'PASS: ssh-keygen differential lookup, host hashing and removal passed'
    'Error: None'
)
foreach ($line in $required) {
    if (-not $text.Contains($line)) { throw "KH01 report is missing: $line" }
}
if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -match '(?m)^FAIL:') {
    throw "VT7 KH01 report did not pass. See $reportPath"
}
Write-Host "PASS: OpenSSH known-host foundation ($reportPath)"
Write-Host "Oracle: ssh-keygen.exe $($sshKeygenInfo.FileVersion), SHA256 $sshKeygenHash"
if ($OutputDirectory) { Write-Host "Return this entire log folder: $reportRoot" }
