[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [string]$BinaryDirectory,
    [string]$OutputDirectory,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = if ($BinaryDirectory) { [IO.Path]::GetFullPath($BinaryDirectory) } else { Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$probePath = Join-Path $binaryRoot 'VT7.SshNetProbe.exe'
if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) { throw "S01 probe is missing: $probePath" }

$runRoot = if ($OutputDirectory) {
    [IO.Path]::GetFullPath($OutputDirectory)
}
else {
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
    Join-Path (Join-Path $binaryRoot 'Logs') ("sshnet-s01-$stamp-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
}
if (Test-Path -LiteralPath $runRoot) { throw "Refusing to replace an existing S01 run: $runRoot" }
if ($runRoot.Contains('"')) { throw 'S01 output path cannot contain a quotation mark.' }

$arguments = @('--output', $runRoot)
if ($SelfTest) { $arguments += '--self-test' }
& $probePath @arguments
if ($LASTEXITCODE -ne 0) { throw "S01 probe failed with exit code $LASTEXITCODE. Logs retained: $runRoot" }
$manifestPath = Join-Path $runRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'S01 probe did not produce its manifest.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -cne 'vt7-sshnet-s01-run-v1' -or -not $manifest.allPassed) { throw 'S01 manifest did not satisfy its schema/pass contract.' }
if ($SelfTest -and $manifest.mode -cne 'self-test') { throw 'S01 self-test returned the wrong mode.' }
if (-not $SelfTest -and $manifest.mode -cne 'network') { throw 'S01 network test returned the wrong mode.' }
$serialized = Get-Content -LiteralPath $manifestPath -Raw
foreach ($forbiddenName in @('serverHostName', 'username', 'expectedFingerprint', 'identityPath', 'password', 'passphrase')) {
    if ($serialized -cmatch ('"' + [regex]::Escape($forbiddenName) + '"\s*:')) { throw "S01 retained forbidden credential field: $forbiddenName" }
}

$manifest.cases | Select-Object name, passed | Format-Table -AutoSize
Write-Host "VT7 S01 characterization completed: $manifestPath"
