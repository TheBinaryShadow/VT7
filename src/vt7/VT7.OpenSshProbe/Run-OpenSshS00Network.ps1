[CmdletBinding()]
param([switch]$VerifyOnly)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Get-Sha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$packageRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$sumPath = Join-Path $packageRoot 'SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $sumPath -PathType Leaf)) { throw 'S00 network package hash inventory is missing.' }
$expected = @{}
foreach ($line in [IO.File]::ReadAllLines($sumPath)) {
    if ($line -notmatch '^([0-9a-f]{64})  ([A-Za-z0-9_.-]+)$') { throw "Invalid S00 network package hash line: $line" }
    $name = $matches[2]
    if ($expected.ContainsKey($name)) { throw "Duplicate S00 network package hash: $name" }
    $expected[$name] = $matches[1].ToUpperInvariant()
}
$actualFiles = @(Get-ChildItem -LiteralPath $packageRoot | Where-Object { -not $_.PSIsContainer -and $_.Name -ne 'SHA256SUMS.txt' })
if ($actualFiles.Count -ne $expected.Count) { throw 'S00 network package file count does not match its hash inventory.' }
foreach ($file in $actualFiles) {
    if (-not $expected.ContainsKey($file.Name)) { throw "Unknown S00 network package file: $($file.Name)" }
    if ((Get-Sha256Hex $file.FullName) -ne $expected[$file.Name]) { throw "S00 network package hash mismatch: $($file.Name)" }
}
if ($VerifyOnly) { Write-Host 'S00 network package verification passed.'; return }

$sshPath = Join-Path $env:ProgramFiles 'OpenSSH\ssh.exe'
if (-not (Test-Path -LiteralPath $sshPath -PathType Leaf)) {
    $command = Get-Command ssh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw 'OpenSSH ssh.exe was not found under Program Files or on PATH.' }
    $sshPath = $command.Source
}
$serverHostName = Read-Host 'Controlled Debian server hostname or IP'
$portText = Read-Host 'SSH port [22]'
$port = if ($portText) { [int]$portText } else { 22 }
$userName = Read-Host 'SSH test username [sshtest]'
if (-not $userName) { $userName = 'sshtest' }
$identityFile = Read-Host 'Full path to the dedicated private key'
$fingerprint = Read-Host 'Trusted Debian Ed25519 host-key fingerprint (SHA256:...)'
$testPath = Join-Path $packageRoot 'Test-VT7OpenSshNetwork.ps1'
$outputRoot = Join-Path $packageRoot 'Logs'
& $testPath -ServerHostName $serverHostName -Port $port -UserName $userName -IdentityFile $identityFile -ExpectedHostKeyFingerprint $fingerprint -SshPath $sshPath -OutputRoot $outputRoot
if (-not $?) { throw 'S00 controlled-server network characterization failed.' }
