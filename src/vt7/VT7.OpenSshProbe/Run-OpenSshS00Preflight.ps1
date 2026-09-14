[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Get-Sha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '')
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

$packageRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$sumPath = Join-Path $packageRoot 'SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $sumPath -PathType Leaf)) {
    throw 'S00 package hash inventory is missing.'
}

$expected = @{}
foreach ($line in [IO.File]::ReadAllLines($sumPath)) {
    if ($line -notmatch '^([0-9a-f]{64})  ([A-Za-z0-9_.-]+)$') {
        throw "Invalid S00 package hash line: $line"
    }
    $name = $matches[2]
    if ($expected.ContainsKey($name)) { throw "Duplicate S00 package hash: $name" }
    $expected[$name] = $matches[1].ToUpperInvariant()
}

$actualFiles = @(Get-ChildItem -LiteralPath $packageRoot -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' })
if ($actualFiles.Count -ne $expected.Count) {
    throw 'S00 package file count does not match its hash inventory.'
}
foreach ($file in $actualFiles) {
    if (-not $expected.ContainsKey($file.Name)) { throw "Unknown S00 package file: $($file.Name)" }
    if ((Get-Sha256Hex $file.FullName) -ne $expected[$file.Name]) {
        throw "S00 package hash mismatch: $($file.Name)"
    }
}

$sshPath = $null
$programFilesCandidate = Join-Path $env:ProgramFiles 'OpenSSH\ssh.exe'
if (Test-Path -LiteralPath $programFilesCandidate -PathType Leaf) {
    $sshPath = $programFilesCandidate
}
else {
    $command = Get-Command ssh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { $sshPath = $command.Source }
}
if (-not $sshPath) {
    throw 'OpenSSH ssh.exe was not found under Program Files or on PATH.'
}

$testPath = Join-Path $packageRoot 'Test-VT7OpenSsh.ps1'
$outputRoot = Join-Path $packageRoot 'Logs'
& $testPath -SshPath $sshPath -OutputRoot $outputRoot
if (-not $?) { throw 'S00 preflight failed.' }
