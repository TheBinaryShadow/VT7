[CmdletBinding()]
param(
    [string]$PackageName = 'VT7-SSHNET-S01-0.6-x64',
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = Join-Path $repositoryRoot 'artifacts\vt7\bin\Release'
$dependencyRoot = Join-Path $repositoryRoot 'artifacts\vt7\deps\nuget'
$noticeRoot = Join-Path $repositoryRoot 'artifacts\vt7\deps\sshnet-source-notices-7b2fd3dbf2c86a80a7b06cea020aa5f821c9902e'
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')

if ($PackageName -notmatch '^VT7-SSHNET-S01-[0-9.]+-x64$') { throw "Invalid S01 package name: $PackageName" }
foreach ($path in @($packageRoot, $archivePath)) { if (Test-Path -LiteralPath $path) { throw "Refusing to replace an existing S01 package: $path" } }
if (-not $NoBuild) { & (Join-Path $PSScriptRoot 'Build-VT7SshNet.ps1') -Configuration Release }

$runtimeNames = @(
    'VT7.SshNetProbe.exe', 'VT7.SshNetProbe.exe.config',
    'Renci.SshNet.dll', 'BouncyCastle.Cryptography.dll',
    'Microsoft.Bcl.AsyncInterfaces.dll', 'Microsoft.Bcl.Cryptography.dll',
    'Microsoft.Extensions.DependencyInjection.Abstractions.dll', 'Microsoft.Extensions.Logging.Abstractions.dll',
    'System.Buffers.dll', 'System.Formats.Asn1.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll',
    'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll'
)
$sourceFiles = [ordered]@{
    'Run-SshNetS01.ps1' = Join-Path $repositoryRoot 'src\vt7\VT7.SshNetProbe\Run-SshNetS01.ps1'
    'RUN-SSHNET-S01.cmd' = Join-Path $repositoryRoot 'src\vt7\VT7.SshNetProbe\RUN-SSHNET-S01.cmd'
    'README.txt' = Join-Path $repositoryRoot 'src\vt7\VT7.SshNetProbe\README.txt'
    'LICENSE.txt' = Join-Path $repositoryRoot 'LICENSE'
    'NOTICE.md' = Join-Path $repositoryRoot 'NOTICE.md'
}

$packages = @(
    @{ Id = 'ssh.net'; Version = '2026.0.0'; Sha256 = 'B2515DE616821198F5CF5530F5EA198912730BBE3504EF4C6AEE00A661FECAC2' },
    @{ Id = 'bouncycastle.cryptography'; Version = '2.7.0'; Sha256 = 'F091FFCCAB4D03993E660BACE277659A79DEE0972F54D7F1F4BD46D680966241' },
    @{ Id = 'microsoft.bcl.cryptography'; Version = '10.0.10'; Sha256 = '4B8EB4562DDC2066E352C0BE51325D5536DF2EE75A15C76DAF809B0B4B19B22D' },
    @{ Id = 'microsoft.extensions.logging.abstractions'; Version = '8.0.3'; Sha256 = 'E4C498D5A13051B4577A148F1D8C3470167215C507E2392069B75DC61322BB74' },
    @{ Id = 'microsoft.bcl.asyncinterfaces'; Version = '8.0.0'; Sha256 = 'F5A5A68B03092AB2ABF68843D4A4AEA25DFBCBE8DD0F13C625CB779B6FC1927C' },
    @{ Id = 'microsoft.extensions.dependencyinjection.abstractions'; Version = '8.0.2'; Sha256 = '51F2DF1100245F10DA54F0BB7E813F277155117777D4FBBAB902214E27372606' },
    @{ Id = 'system.buffers'; Version = '4.6.1'; Sha256 = 'B00451E91D016FBEC091AD1E361F3A7015E1D91D4047F7E48A74455B2A673D79' },
    @{ Id = 'system.formats.asn1'; Version = '10.0.10'; Sha256 = '21963AB1DFEE2B2B87E7B6348A3A23A4772AF500247E4401B0BBE3156CEDB29C' },
    @{ Id = 'system.memory'; Version = '4.6.3'; Sha256 = '26078AEB758C9AE985E8BF851F973026061DA6A5EB4837204D0C2D2204C72955' },
    @{ Id = 'system.numerics.vectors'; Version = '4.6.1'; Sha256 = '2BC500A86DCB02F2032D6D877F9E2D6E9E4A79080E57239B4198679D4031F2C7' },
    @{ Id = 'system.runtime.compilerservices.unsafe'; Version = '6.1.2'; Sha256 = '5F6A7F53AF3465F92BEB6DA873EBE0E496206C313313B98BADEE4355A6B25937' },
    @{ Id = 'system.threading.tasks.extensions'; Version = '4.5.4'; Sha256 = 'A304A963CC0796C5179F9C6B7D8022BBCE3B2FA7C029EB6196F631F7B462D678' },
    @{ Id = 'system.valuetuple'; Version = '4.6.2'; Sha256 = '76FD0E366A2B90655FD15D557B0B79504197748358CB578FE3193F6D97BDD9AA' }
)
foreach ($name in $runtimeNames) {
    $path = Join-Path $binaryRoot $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "S01 runtime file is missing: $name" }
}
foreach ($path in $sourceFiles.Values) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "S01 package source is missing: $path" } }

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
foreach ($name in $runtimeNames) { Copy-Item -LiteralPath (Join-Path $binaryRoot $name) -Destination (Join-Path $packageRoot $name) }
foreach ($name in $sourceFiles.Keys) { Copy-Item -LiteralPath $sourceFiles[$name] -Destination (Join-Path $packageRoot $name) }
$fixtureRoot = Join-Path $packageRoot 'fixtures'
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
foreach ($name in @('s01-encrypted-test-key', 's01-encrypted-test-key.pub')) {
    $source = Join-Path (Join-Path $binaryRoot 'fixtures') $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "S01 encrypted-key fixture is missing: $source" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $fixtureRoot $name)
}

$licensesRoot = Join-Path $packageRoot 'licenses'
New-Item -ItemType Directory -Path $licensesRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $noticeRoot 'SSH.NET-LICENSE.txt') -Destination $licensesRoot
Copy-Item -LiteralPath (Join-Path $noticeRoot 'SSH.NET-THIRD-PARTY-NOTICES.txt') -Destination $licensesRoot
$microsoftLicense = Join-Path $dependencyRoot 'microsoft.bcl.asyncinterfaces\8.0.0\LICENSE.TXT'
Copy-Item -LiteralPath $microsoftLicense -Destination (Join-Path $licensesRoot 'Microsoft-MIT.txt')

$dependencyInventory = New-Object System.Collections.Generic.List[object]
foreach ($package in $packages) {
    $sourceRoot = Join-Path $dependencyRoot ($package.Id + '\' + $package.Version)
    $nupkg = Join-Path $sourceRoot ($package.Id + '.' + $package.Version + '.nupkg')
    if ((Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash -ne $package.Sha256) { throw "S01 dependency hash mismatch: $($package.Id) $($package.Version)" }
    $destination = Join-Path $licensesRoot ($package.Id + '-' + $package.Version)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $noticeFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File | Where-Object { $_.Name -match '^(LICENSE|THIRD-PARTY-NOTICES|README|PACKAGE)\.' -or $_.Extension -eq '.nuspec' })
    foreach ($file in $noticeFiles) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $destination $file.Name) }
    $dependencyInventory.Add([pscustomobject]@{ id = $package.Id; version = $package.Version; nupkgSha256 = $package.Sha256; noticeFiles = @($noticeFiles.Name | Sort-Object) })
}

$head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
$manifest = [ordered]@{
    schema = 'vt7-sshnet-s01-package-v1'
    package = $PackageName
    createdUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    targetFramework = 'net48'
    sshNetVersion = '2026.0.0'
    sshNetCommit = '7b2fd3dbf2c86a80a7b06cea020aa5f821c9902e'
    sourceGitHead = $head
    sourceGitDirty = ($status.Count -gt 0)
    credentialsRetained = $false
    dependencies = $dependencyInventory.ToArray()
    scope = 'S01 strict trust, structured authentication, modern negotiation, command bytes, PTY geometry, resize, drain, cancellation, disconnect and session isolation'
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'DEPENDENCIES.json'), ($manifest | ConvertTo-Json -Depth 8), $utf8)

$selfTestRoot = Join-Path (Join-Path $repositoryRoot 'artifacts\vt7\reports\Release') ('sshnet-s01-package-selftest-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
& (Join-Path $PSScriptRoot 'Test-VT7SshNet.ps1') -Configuration Release -BinaryDirectory $packageRoot -OutputDirectory $selfTestRoot -SelfTest

$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -Recurse | Where-Object { -not $_.PSIsContainer } | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($packageRoot.Length + 1).Replace([IO.Path]::DirectorySeparatorChar, '/')
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $relative
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)
& (Join-Path $packageRoot 'Run-SshNetS01.ps1') -VerifyOnly

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -Recurse | Where-Object { -not $_.PSIsContainer }) {
    $relative = $file.FullName.Substring($packageRoot.Length + 1).Replace([IO.Path]::DirectorySeparatorChar, '/')
    $expected[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $name = $entry.FullName.Replace('\', '/')
        if ($name.StartsWith('/') -or $name.Split('/') -contains '..') { throw "Unsafe S01 ZIP entry: $name" }
        if ($seen.ContainsKey($name) -or -not $expected.ContainsKey($name)) { throw "Duplicate or unknown S01 ZIP entry: $name" }
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$name]) { throw "S01 ZIP entry hash mismatch: $name" }
        $seen[$name] = $true
    }
}
finally { $archive.Dispose() }
if ($seen.Count -ne $expected.Count) { throw 'S01 ZIP is missing one or more staged files.' }

[pscustomobject]@{
    PackageDirectory = $packageRoot
    ArchivePath = $archivePath
    ArchiveSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    Bytes = (Get-Item -LiteralPath $archivePath).Length
    Files = $seen.Count
    SelfTest = Join-Path $selfTestRoot 'manifest.json'
}
