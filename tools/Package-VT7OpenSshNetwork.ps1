[CmdletBinding()]
param([string]$PackageName = 'VT7-OpenSSH-S00-Network-0.2-x64')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')
if ($PackageName -notmatch '^VT7-OpenSSH-S00-Network-[0-9.]+-x64$') { throw "Invalid S00 network package name: $PackageName" }
foreach ($path in @($packageRoot, $archivePath)) { if (Test-Path -LiteralPath $path) { throw "Refusing to replace an existing S00 network package: $path" } }
$inputs = [ordered]@{
    'Test-VT7OpenSshNetwork.ps1' = Join-Path $PSScriptRoot 'Test-VT7OpenSshNetwork.ps1'
    'Run-OpenSshS00Network.ps1' = Join-Path $repositoryRoot 'src\vt7\VT7.OpenSshProbe\Run-OpenSshS00Network.ps1'
    'RUN-OPENSSH-S00-NETWORK.cmd' = Join-Path $repositoryRoot 'src\vt7\VT7.OpenSshProbe\RUN-OPENSSH-S00-NETWORK.cmd'
    'README.txt' = Join-Path $repositoryRoot 'src\vt7\VT7.OpenSshProbe\NETWORK-README.txt'
    'LICENSE.txt' = Join-Path $repositoryRoot 'LICENSE'
    'NOTICE.md' = Join-Path $repositoryRoot 'NOTICE.md'
}
foreach ($source in $inputs.Values) { if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "S00 network package input is missing: $source" } }
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
foreach ($name in $inputs.Keys) { Copy-Item -LiteralPath $inputs[$name] -Destination (Join-Path $packageRoot $name) }
$head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
$manifest = [ordered]@{
    schema = 'vt7-openssh-s00-network-package-v1'
    package = $PackageName
    createdUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    sourceGitHead = $head
    sourceGitDirty = ($status.Count -gt 0)
    bundledOpenSsh = $false
    expectedSshSha256 = '6890C128C86CC2C38AAD9FCB32A82B851FF3D38C714A1F656B8E445D7CD5E1C6'
    server = 'User-supplied controlled Debian 12 endpoint; identity and trust values are runtime-only'
    scope = 'S00 strict trust, key authentication, negotiated algorithms, non-PTY bytes, initial PTY, active cancellation and final drain'
    disposition = 'S00 complete: exact client source rejects redirected interactive PTY geometry; retain this runner only for reproducibility'
    successor = 'SSH.NET 2026.0.0 is approved for a separately versioned S01 diagnostic'
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
$hashLines = @(Get-ChildItem -LiteralPath $packageRoot | Where-Object { -not $_.PSIsContainer } | Sort-Object Name | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.Name })
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)

& (Join-Path $packageRoot 'Run-OpenSshS00Network.ps1') -VerifyOnly
if (-not $?) { throw 'Packaged S00 network self-verification failed.' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot | Where-Object { -not $_.PSIsContainer }) { $expected[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name) -or $entry.FullName -ne $entry.Name) { throw "Unexpected S00 network ZIP entry: $($entry.FullName)" }
        if ($seen.ContainsKey($entry.Name) -or -not $expected.ContainsKey($entry.Name)) { throw "Duplicate or unknown S00 network ZIP entry: $($entry.Name)" }
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$entry.Name]) { throw "S00 network ZIP entry hash mismatch: $($entry.Name)" }
        $seen[$entry.Name] = $true
    }
}
finally { $archive.Dispose() }
if ($seen.Count -ne $expected.Count) { throw 'S00 network ZIP is missing one or more staged files.' }
[pscustomobject]@{ PackageDirectory = $packageRoot; ArchivePath = $archivePath; ArchiveSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash; Bytes = (Get-Item -LiteralPath $archivePath).Length; Files = $seen.Count }
