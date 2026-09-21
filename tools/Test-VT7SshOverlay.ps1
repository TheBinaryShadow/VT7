[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [string]$OutputDirectory,
    [switch]$AllowMissingPowerShell7
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
if ($env:VT7_ALLOW_MISSING_POWERSHELL7 -eq '1') { $AllowMissingPowerShell7 = $true }

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
$shim = Join-Path $binaryRoot 'shim\ssh.exe'
$bypass = Join-Path $binaryRoot 'shim\ssh-system.exe'
foreach ($path in @($shim, $bypass)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Typed-SSH shim is missing: $path" }
}
if ((Get-VT7Sha256 -Path $shim) -ne (Get-VT7Sha256 -Path $bypass)) {
    throw 'ssh.exe and ssh-system.exe are not the same reviewed shim binary.'
}

$externalCandidates = New-Object System.Collections.Generic.List[string]
foreach ($root in @($env:ProgramW6432, $env:ProgramFiles)) {
    if ($root) { $externalCandidates.Add((Join-Path $root 'OpenSSH\ssh.exe')) }
}
if ($env:SystemRoot) { $externalCandidates.Add((Join-Path $env:SystemRoot 'System32\OpenSSH\ssh.exe')) }
foreach ($directory in ($env:PATH -split ';')) {
    if ($directory) { $externalCandidates.Add((Join-Path $directory.Trim('"') 'ssh.exe')) }
}
$external = $externalCandidates | Where-Object {
    (Test-Path -LiteralPath $_ -PathType Leaf) -and
    -not [IO.Path]::GetFullPath($_).StartsWith([IO.Path]::GetFullPath((Join-Path $binaryRoot 'shim')), [StringComparison]::OrdinalIgnoreCase)
} | Select-Object -First 1
if (-not $external) { throw 'No external OpenSSH ssh.exe was found for exact fallback.' }

$reportRoot = if ($OutputDirectory) {
    $parent = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $identity = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    Join-Path $parent ('ssh-overlay-' + $identity)
} else { Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration\SshOverlay" }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

& (Join-Path $PSScriptRoot 'Test-VT7SessionStream.ps1') -Configuration $Configuration -BinaryDirectory $binaryRoot -OutputDirectory (Join-Path $reportRoot 'session')
& (Join-Path $PSScriptRoot 'Test-VT7SessionOutbound.ps1') -Configuration $Configuration -BinaryDirectory $binaryRoot -OutputDirectory (Join-Path $reportRoot 'outbound')
& (Join-Path $PSScriptRoot 'Test-VT7SshNetFoundation.ps1') -Configuration $Configuration -BinaryDirectory $binaryRoot -OutputDirectory (Join-Path $reportRoot 'sshnet')
$h01 = @{
    Configuration = $Configuration
    BinaryDirectory = $binaryRoot
    OutputDirectory = (Join-Path $reportRoot 'h01')
}
if ($AllowMissingPowerShell7) { $h01.AllowMissingPowerShell7 = $true }
& (Join-Path $PSScriptRoot 'Test-VT7H01.ps1') @h01

$environment = @(
    'CapturedUtc=' + [DateTime]::UtcNow.ToString('o')
    'ExternalSsh=' + [IO.Path]::GetFullPath($external)
    'ExternalSshSHA256=' + (Get-VT7Sha256 -Path $external)
    'Result=PASS'
)
[IO.File]::WriteAllLines((Join-Path $reportRoot 'OVERLAY-ENVIRONMENT.txt'), $environment,
    (New-Object Text.UTF8Encoding($false)))
Write-Host "PASS: typed SSH overlay prerequisites and regression corpus ($reportRoot)"
if ($OutputDirectory) { Write-Host "Return this entire log folder: $reportRoot" }
