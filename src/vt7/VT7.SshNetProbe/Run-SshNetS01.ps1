[CmdletBinding()]
param(
    [switch]$VerifyOnly,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Get-Sha256Hex([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$packageRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$sumPath = Join-Path $packageRoot 'SHA256SUMS.txt'
$logsRoot = Join-Path $packageRoot 'Logs'
$logsBoundary = [IO.Path]::GetFullPath($logsRoot) + [IO.Path]::DirectorySeparatorChar
if (-not (Test-Path -LiteralPath $sumPath -PathType Leaf)) { throw 'S01 package hash inventory is missing.' }
$expected = @{}
foreach ($line in [IO.File]::ReadAllLines($sumPath)) {
    if ($line -notmatch '^([0-9a-f]{64})  ([A-Za-z0-9_.\\/-]+)$') { throw "Invalid S01 package hash line: $line" }
    $name = $matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
    if ($name.Split([IO.Path]::DirectorySeparatorChar) -contains '..') { throw "Unsafe S01 package hash path: $name" }
    if ($expected.ContainsKey($name)) { throw "Duplicate S01 package hash: $name" }
    $expected[$name] = $matches[1].ToUpperInvariant()
}
$actualFiles = @(Get-ChildItem -LiteralPath $packageRoot -Recurse | Where-Object {
    -not $_.PSIsContainer -and $_.FullName -ne $sumPath -and -not $_.FullName.StartsWith($logsBoundary, [StringComparison]::OrdinalIgnoreCase)
})
if ($actualFiles.Count -ne $expected.Count) { throw 'S01 package file count does not match its hash inventory.' }
foreach ($file in $actualFiles) {
    $relative = $file.FullName.Substring($packageRoot.Length + 1)
    if (-not $expected.ContainsKey($relative)) { throw "Unknown S01 package file: $relative" }
    if ((Get-Sha256Hex $file.FullName) -ne $expected[$relative]) { throw "S01 package hash mismatch: $relative" }
}
if ($VerifyOnly) { Write-Host 'S01 package verification passed.'; return }

$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$runRoot = Join-Path $logsRoot ("sshnet-s01-$stamp-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$probePath = Join-Path $packageRoot 'VT7.SshNetProbe.exe'
$expectedMode = if ($SelfTest) { 'self-test' } else { 'network' }
if ($SelfTest) { & $probePath --output $runRoot --self-test }
else { & $probePath --output $runRoot }
if ($LASTEXITCODE -ne 0) { throw "S01 $expectedMode characterization failed with exit code $LASTEXITCODE. Logs retained: $runRoot" }
$manifestPath = Join-Path $runRoot 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -cne 'vt7-sshnet-s01-run-v1' -or $manifest.mode -cne $expectedMode -or -not $manifest.allPassed) { throw "S01 $expectedMode manifest did not satisfy its acceptance contract." }
Write-Host "S01 $expectedMode characterization passed: $manifestPath"
