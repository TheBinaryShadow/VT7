[CmdletBinding()]
param(
    [string]$PackageName = 'VT7-KnownHosts-KH01-0.8-x64',
    [switch]$NoBuild
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = Join-Path $repositoryRoot 'artifacts\vt7\bin\Release'
$dependencyRoot = Join-Path $repositoryRoot 'artifacts\vt7\deps'
$nugetRoot = Join-Path $dependencyRoot 'nuget'
$noticeRoot = Join-Path $dependencyRoot 'sshnet-source-notices-f099365c9d4cf2ade92b92c203bbb2b345d2cd74'
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')
if ($PackageName -notmatch '^VT7-KnownHosts-KH01-0\.8-x64$') { throw "Invalid KH01.4 package name: $PackageName" }
foreach ($path in @($packageRoot, $archivePath)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to replace an existing KH01.4 package: $path" }
}
if (-not $NoBuild) { & (Join-Path $PSScriptRoot 'Build-VT7.ps1') -Configuration Release }

$hostPath = Join-Path $binaryRoot 'VT7.Host.exe'
if ([Diagnostics.FileVersionInfo]::GetVersionInfo($hostPath).FileVersion -ne '0.12.3.0') { throw 'Expected VT7.Host 0.12.3.0.' }
$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installationPath = (& $vswherePath -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
if (-not $installationPath) { throw 'Visual Studio 2022 C++ tools were not found.' }
$redistVersion = [IO.File]::ReadAllText((Join-Path $installationPath 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt')).Trim()
if ($redistVersion -ne '14.44.35112') { throw "Unexpected Visual C++ runtime version: $redistVersion" }
$redistRoot = Join-Path $installationPath "VC\Redist\MSVC\$redistVersion\x64\Microsoft.VC143.CRT"

$runtimeNames = @(
    'Renci.SshNet.dll', 'BouncyCastle.Cryptography.dll',
    'Microsoft.Bcl.AsyncInterfaces.dll', 'Microsoft.Bcl.Cryptography.dll',
    'Microsoft.Extensions.DependencyInjection.Abstractions.dll', 'Microsoft.Extensions.Logging.Abstractions.dll',
    'System.Buffers.dll', 'System.Formats.Asn1.dll', 'System.Memory.dll', 'System.Numerics.Vectors.dll',
    'System.Runtime.CompilerServices.Unsafe.dll', 'System.Threading.Tasks.Extensions.dll'
)
$inputs = [ordered]@{
    'VT7.Host.exe' = $hostPath
    'VT7.Host.exe.config' = Join-Path $binaryRoot 'VT7.Host.exe.config'
    'VT7.Native.dll' = Join-Path $binaryRoot 'VT7.Native.dll'
    'winpty.dll' = Join-Path $binaryRoot 'winpty.dll'
    'winpty-agent.exe' = Join-Path $binaryRoot 'winpty-agent.exe'
    'winpty-LICENSE.txt' = Join-Path $binaryRoot 'winpty-LICENSE.txt'
    'Test-VT7SshOverlay.ps1' = Join-Path $PSScriptRoot 'Test-VT7SshOverlay.ps1'
    'Test-VT7SshNetFoundation.ps1' = Join-Path $PSScriptRoot 'Test-VT7SshNetFoundation.ps1'
    'Test-VT7H01.ps1' = Join-Path $PSScriptRoot 'Test-VT7H01.ps1'
    'Test-VT7SessionStream.ps1' = Join-Path $PSScriptRoot 'Test-VT7SessionStream.ps1'
    'Test-VT7SessionOutbound.ps1' = Join-Path $PSScriptRoot 'Test-VT7SessionOutbound.ps1'
    'Test-VT7KnownHosts.ps1' = Join-Path $PSScriptRoot 'Test-VT7KnownHosts.ps1'
    'VT7.WinPtyFixture.exe' = Join-Path $binaryRoot 'VT7.WinPtyFixture.exe'
    'RUN-SSHNET-OVERLAY.cmd' = Join-Path $repositoryRoot 'src\vt7\packaging\RUN-SSHNET-OVERLAY.cmd'
    'RUN-KNOWN-HOSTS-KH01-4.cmd' = Join-Path $repositoryRoot 'src\vt7\packaging\RUN-KNOWN-HOSTS-KH01-4.cmd'
    'RUN-VT7-COMMAND-PROMPT.cmd' = Join-Path $repositoryRoot 'src\vt7\packaging\RUN-VT7-COMMAND-PROMPT.cmd'
    'RUN-VT7-WINDOWS-POWERSHELL.cmd' = Join-Path $repositoryRoot 'src\vt7\packaging\RUN-VT7-WINDOWS-POWERSHELL.cmd'
    'README.txt' = Join-Path $repositoryRoot 'src\vt7\packaging\KNOWN-HOSTS-KH01-4-INHERITED-ACL-README.txt'
    'LICENSE.txt' = Join-Path $repositoryRoot 'LICENSE'
    'NOTICE.md' = Join-Path $repositoryRoot 'NOTICE.md'
    'msvcp140.dll' = Join-Path $redistRoot 'msvcp140.dll'
    'vcruntime140.dll' = Join-Path $redistRoot 'vcruntime140.dll'
    'vcruntime140_1.dll' = Join-Path $redistRoot 'vcruntime140_1.dll'
}
foreach ($name in $runtimeNames) { $inputs[$name] = Join-Path $binaryRoot $name }
foreach ($source in $inputs.Values) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "KH01.4 package input is missing: $source" }
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
foreach ($name in $inputs.Keys) { Copy-Item -LiteralPath $inputs[$name] -Destination (Join-Path $packageRoot $name) }
$shimRoot = Join-Path $packageRoot 'shim'
New-Item -ItemType Directory -Path $shimRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $binaryRoot 'shim\ssh.exe') -Destination (Join-Path $shimRoot 'ssh.exe')
Copy-Item -LiteralPath (Join-Path $binaryRoot 'shim\ssh-system.exe') -Destination (Join-Path $shimRoot 'ssh-system.exe')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'oss\unifont') -Destination (Join-Path $packageRoot 'fonts') -Recurse

$licenseRoot = Join-Path $packageRoot 'licenses'
New-Item -ItemType Directory -Path $licenseRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'wil-b6ec76a2d9a609897f25a7fa0a0bdf4238e94e35\LICENSE') -Destination (Join-Path $licenseRoot 'WIL.txt')
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'GSL-152d6eb989a1ecd23fe9c9cfb2fb8cfc7c0cd0c1\LICENSE') -Destination (Join-Path $licenseRoot 'GSL.txt')
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'fmt-407c905e45ad75fc29bf0f9bb7c5c2fd3475976f\LICENSE') -Destination (Join-Path $licenseRoot 'fmt.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'oss\chromium\LICENSE') -Destination (Join-Path $licenseRoot 'chromium.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'oss\stb\LICENSE') -Destination (Join-Path $licenseRoot 'stb.txt')
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'winpty-0.4.3-msvc2015\LICENSE') -Destination (Join-Path $licenseRoot 'WinPTY.txt')
Copy-Item -LiteralPath (Join-Path $noticeRoot 'SSH.NET-LICENSE.txt') -Destination $licenseRoot
Copy-Item -LiteralPath (Join-Path $noticeRoot 'SSH.NET-THIRD-PARTY-NOTICES.txt') -Destination $licenseRoot
Copy-Item -LiteralPath (Join-Path $nugetRoot 'microsoft.bcl.asyncinterfaces\8.0.0\LICENSE.TXT') -Destination (Join-Path $licenseRoot 'Microsoft-MIT.txt')

$packages = @(
    @{ Id = 'ssh.net'; Version = '2026.0.1-prerelease.6'; Sha256 = '3981BA4F5A36DADFFDAC19BA8B8F207F594F57B3BA043A794277678669FBC35C' },
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
$dependencyInventory = New-Object System.Collections.Generic.List[object]
foreach ($package in $packages) {
    $sourceRoot = Join-Path $nugetRoot ($package.Id + '\' + $package.Version)
    $nupkg = Join-Path $sourceRoot ($package.Id + '.' + $package.Version + '.nupkg')
    if ((Get-FileHash -LiteralPath $nupkg -Algorithm SHA256).Hash -ne $package.Sha256) {
        throw "SSH.NET dependency hash mismatch: $($package.Id) $($package.Version)"
    }
    $destination = Join-Path $licenseRoot ($package.Id + '-' + $package.Version)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $noticeFiles = @(Get-ChildItem -LiteralPath $sourceRoot | Where-Object {
        -not $_.PSIsContainer -and ($_.Name -match '^(LICENSE|THIRD-PARTY-NOTICES|README|PACKAGE)\.' -or $_.Extension -eq '.nuspec')
    })
    foreach ($file in $noticeFiles) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $destination $file.Name) }
    $dependencyInventory.Add([pscustomobject]@{
        id = $package.Id; version = $package.Version; nupkgSha256 = $package.Sha256
        noticeFiles = @($noticeFiles.Name | Sort-Object)
    })
}

& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -BinaryDirectory $packageRoot -AllowAnyCpuManaged
$symbolRoot = Join-Path $packageRoot 'symbols'
New-Item -ItemType Directory -Path $symbolRoot -Force | Out-Null
foreach ($symbol in @('VT7.Host.pdb', 'VT7.Native.pdb', 'VT7.Core.pdb', 'VT7.SshShim.pdb', 'VT7.WinPtyFixture.pdb')) {
    Copy-Item -LiteralPath (Join-Path $binaryRoot $symbol) -Destination $symbolRoot
}

$head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
$manifest = [ordered]@{
    schema = 'vt7-known-hosts-kh01-4-package-v1'
    package = $PackageName
    createdUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    applicationVersion = '0.12.3'
    nativeAbi = 11
    targetFramework = 'net48'
    sshNetVersion = '2026.0.1-prerelease.6'
    sshNetCommit = 'f099365c9d4cf2ade92b92c203bbb2b345d2cd74'
    sourceGitHead = $head
    sourceGitDirty = ($status.Count -gt 0)
    scope = 'KH01.4 changed-key review and host-certificate policy with structural owner/group/DACL verification before selected user-record removal, inherited-ACL fixture correction, exact .old backup and legible key rows'
    networkConnections = $true
    credentialsRetained = $false
    typedSshEnabled = $true
    productionKnownHostsIntegration = $true
    knownHostsWriteEnabled = $true
    knownHostsRemovalEnabled = $true
    hostCertificatesEnabled = $true
    dependencies = $dependencyInventory.ToArray()
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 8), $utf8)
$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -Recurse | Where-Object { -not $_.PSIsContainer } | Sort-Object FullName | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)

$localTestRoot = Join-Path $packageParent ($PackageName + '-local-test')
$batchTestRoot = Join-Path $packageParent ($PackageName + ' batch path with spaces')
foreach ($testPath in @($localTestRoot, $batchTestRoot)) {
    if (Test-Path -LiteralPath $testPath) { throw "Refusing to replace an existing KH01.4 test directory: $testPath" }
}
$oldNoPause = $env:VT7_TEST_NO_PAUSE
$oldOutputDirectory = $env:VT7_TEST_OUTPUT_DIRECTORY
$oldAllowMissingPowerShell7 = $env:VT7_ALLOW_MISSING_POWERSHELL7
$oldExpectedSshKeygenFileVersion = $env:VT7_TEST_EXPECTED_SSH_KEYGEN_FILE_VERSION
try {
    Copy-Item -LiteralPath $packageRoot -Destination $batchTestRoot -Recurse
    $env:VT7_TEST_NO_PAUSE = '1'
    $env:VT7_TEST_OUTPUT_DIRECTORY = $localTestRoot
    $env:VT7_ALLOW_MISSING_POWERSHELL7 = '1'
    $localSshKeygen = (Get-Command ssh-keygen.exe -ErrorAction Stop).Source
    $env:VT7_TEST_EXPECTED_SSH_KEYGEN_FILE_VERSION = [Diagnostics.FileVersionInfo]::GetVersionInfo($localSshKeygen).FileVersion
    foreach ($runner in @('RUN-SSHNET-OVERLAY.cmd', 'RUN-KNOWN-HOSTS-KH01-4.cmd')) {
        $batchRunner = Join-Path $batchTestRoot $runner
        & (Join-Path $env:SystemRoot 'System32\cmd.exe') /d /c ('"' + $batchRunner + '"')
        if ($LASTEXITCODE -ne 0) { throw "Packaged KH01.4 launcher $runner failed with exit code $LASTEXITCODE." }
    }
}
finally {
    $env:VT7_TEST_NO_PAUSE = $oldNoPause
    $env:VT7_TEST_OUTPUT_DIRECTORY = $oldOutputDirectory
    $env:VT7_ALLOW_MISSING_POWERSHELL7 = $oldAllowMissingPowerShell7
    $env:VT7_TEST_EXPECTED_SSH_KEYGEN_FILE_VERSION = $oldExpectedSshKeygenFileVersion
    foreach ($testPath in @($localTestRoot, $batchTestRoot)) {
        if (Test-Path -LiteralPath $testPath) {
            $boundary = [IO.Path]::GetFullPath($packageParent).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            $resolved = [IO.Path]::GetFullPath($testPath)
            if (-not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing cleanup outside package directory: $resolved" }
            for ($attempt = 1; $attempt -le 10; ++$attempt) {
                try {
                    Remove-Item -LiteralPath $testPath -Recurse -Force
                    break
                }
                catch {
                    if ($attempt -eq 10) { throw }
                    Start-Sleep -Milliseconds 250
                }
            }
        }
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -Recurse | Where-Object { -not $_.PSIsContainer }) {
    $relative = $file.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    $expected[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $name = $entry.FullName.Replace('\', '/')
        if ($name.StartsWith('/') -or $name.Split('/') -contains '..') { throw "Unsafe ZIP entry: $name" }
        if ($seen.ContainsKey($name) -or -not $expected.ContainsKey($name)) { throw "Duplicate or unknown ZIP entry: $name" }
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$name]) { throw "ZIP entry hash mismatch: $name" }
        $seen[$name] = $true
    }
}
finally { $archive.Dispose() }
if ($seen.Count -ne $expected.Count) { throw 'KH01.4 ZIP is missing one or more staged files.' }

[pscustomobject]@{
    PackageDirectory = $packageRoot
    ArchivePath = $archivePath
    ArchiveSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    Bytes = (Get-Item -LiteralPath $archivePath).Length
    Files = $seen.Count
}
