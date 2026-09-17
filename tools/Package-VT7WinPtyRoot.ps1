[CmdletBinding()]
param(
    [string]$PackageName = 'VT7-WinPty-Root-0.5.2-x64',
    [switch]$NoBuild
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = Join-Path $repositoryRoot 'artifacts\vt7\bin\Release'
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')
if ($PackageName -notmatch '^VT7-WinPty-Root-0\.5\.2-x64$') { throw "Invalid WinPTY-root package name: $PackageName" }
foreach ($path in @($packageRoot, $archivePath)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to replace an existing WinPTY-root package: $path" }
}
if (-not $NoBuild) { & (Join-Path $PSScriptRoot 'Build-VT7.ps1') -Configuration Release }

$hostPath = Join-Path $binaryRoot 'VT7.Host.exe'
$native = Join-Path $binaryRoot 'VT7.Native.dll'
if ([Diagnostics.FileVersionInfo]::GetVersionInfo($hostPath).FileVersion -ne '0.5.2.0') { throw 'Expected VT7.Host 0.5.2.0.' }
if (-not (Test-Path -LiteralPath $native -PathType Leaf)) { throw "Missing native payload: $native" }

$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installationPath = (& $vswherePath -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
if (-not $installationPath) { throw 'Visual Studio 2022 C++ tools were not found.' }
$redistVersion = [IO.File]::ReadAllText((Join-Path $installationPath 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt')).Trim()
if ($redistVersion -ne '14.44.35112') { throw "Unexpected Visual C++ runtime version: $redistVersion" }
$redistRoot = Join-Path $installationPath "VC\Redist\MSVC\$redistVersion\x64\Microsoft.VC143.CRT"

$inputs = [ordered]@{
    'VT7.Host.exe' = $hostPath
    'VT7.Host.exe.config' = Join-Path $binaryRoot 'VT7.Host.exe.config'
    'VT7.Native.dll' = $native
    'winpty.dll' = Join-Path $binaryRoot 'winpty.dll'
    'winpty-agent.exe' = Join-Path $binaryRoot 'winpty-agent.exe'
    'winpty-LICENSE.txt' = Join-Path $binaryRoot 'winpty-LICENSE.txt'
    'Test-VT7SessionOutbound.ps1' = Join-Path $PSScriptRoot 'Test-VT7SessionOutbound.ps1'
    'Test-VT7SessionStream.ps1' = Join-Path $PSScriptRoot 'Test-VT7SessionStream.ps1'
    'Test-VT7WinPtySession.ps1' = Join-Path $PSScriptRoot 'Test-VT7WinPtySession.ps1'
    'RUN-WINPTY-ROOT.cmd' = Join-Path $repositoryRoot 'src\vt7\packaging\RUN-WINPTY-ROOT.cmd'
    'RUN-VT7-COMMAND-PROMPT.cmd' = Join-Path $repositoryRoot 'src\vt7\packaging\RUN-VT7-COMMAND-PROMPT.cmd'
    'README.txt' = Join-Path $repositoryRoot 'src\vt7\packaging\WINPTY-ROOT-README.txt'
    'LICENSE.txt' = Join-Path $repositoryRoot 'LICENSE'
    'NOTICE.md' = Join-Path $repositoryRoot 'NOTICE.md'
    'msvcp140.dll' = Join-Path $redistRoot 'msvcp140.dll'
    'vcruntime140.dll' = Join-Path $redistRoot 'vcruntime140.dll'
    'vcruntime140_1.dll' = Join-Path $redistRoot 'vcruntime140_1.dll'
}
foreach ($source in $inputs.Values) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "WinPTY-root package input is missing: $source" }
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
foreach ($name in $inputs.Keys) { Copy-Item -LiteralPath $inputs[$name] -Destination (Join-Path $packageRoot $name) }
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'oss\unifont') -Destination (Join-Path $packageRoot 'fonts') -Recurse
$licenseRoot = Join-Path $packageRoot 'licenses'
New-Item -ItemType Directory -Path $licenseRoot -Force | Out-Null
$dependencyRoot = Join-Path $repositoryRoot 'artifacts\vt7\deps'
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'wil-b6ec76a2d9a609897f25a7fa0a0bdf4238e94e35\LICENSE') -Destination (Join-Path $licenseRoot 'WIL.txt')
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'GSL-152d6eb989a1ecd23fe9c9cfb2fb8cfc7c0cd0c1\LICENSE') -Destination (Join-Path $licenseRoot 'GSL.txt')
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'fmt-407c905e45ad75fc29bf0f9bb7c5c2fd3475976f\LICENSE') -Destination (Join-Path $licenseRoot 'fmt.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'oss\chromium\LICENSE') -Destination (Join-Path $licenseRoot 'chromium.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'oss\stb\LICENSE') -Destination (Join-Path $licenseRoot 'stb.txt')
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'winpty-0.4.3-msvc2015\LICENSE') -Destination (Join-Path $licenseRoot 'WinPTY.txt')

& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -BinaryDirectory $packageRoot

$symbolRoot = Join-Path $packageRoot 'symbols'
New-Item -ItemType Directory -Path $symbolRoot -Force | Out-Null
foreach ($symbol in @('VT7.Host.pdb', 'VT7.Native.pdb', 'VT7.Core.pdb')) {
    Copy-Item -LiteralPath (Join-Path $binaryRoot $symbol) -Destination $symbolRoot
}
$head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
$manifest = [ordered]@{
    schema = 'vt7-winpty-root-package-v1'
    package = $PackageName
    createdUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    applicationVersion = '0.5.2'
    nativeAbi = 11
    sourceGitHead = $head
    sourceGitDirty = ($status.Count -gt 0)
    scope = 'Milestone 3B.1 Command Prompt root transport through pinned WinPTY 0.4.3 with native mouse-wheel scrollback and committed-character input snap'
    winPtyVersion = '0.4.3'
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)

$localTestRoot = Join-Path $packageParent ($PackageName + '-local-test')
if (Test-Path -LiteralPath $localTestRoot) { throw "Refusing to replace an existing package test directory: $localTestRoot" }
try {
    & (Join-Path $PSScriptRoot 'Test-VT7SessionOutbound.ps1') -Configuration Release -BinaryDirectory $packageRoot -OutputDirectory $localTestRoot
    & (Join-Path $PSScriptRoot 'Test-VT7SessionStream.ps1') -Configuration Release -BinaryDirectory $packageRoot -OutputDirectory $localTestRoot
    & (Join-Path $PSScriptRoot 'Test-VT7WinPtySession.ps1') -Configuration Release -BinaryDirectory $packageRoot -OutputDirectory $localTestRoot
}
finally {
    if (Test-Path -LiteralPath $localTestRoot) { Remove-Item -LiteralPath $localTestRoot -Recurse -Force }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Path $packageParent -Force | Out-Null
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -File -Recurse) {
    $expected[$file.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $name = $entry.FullName.Replace('\', '/')
        if ($seen.ContainsKey($name) -or -not $expected.ContainsKey($name)) { throw "Duplicate or unknown ZIP entry: $name" }
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$name]) { throw "ZIP entry hash mismatch: $name" }
        $seen[$name] = $true
    }
}
finally { $archive.Dispose() }
if ($seen.Count -ne $expected.Count) { throw 'WinPTY-root ZIP is missing one or more staged files.' }

[pscustomobject]@{
    PackageDirectory = $packageRoot
    ArchivePath = $archivePath
    ArchiveSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    Bytes = (Get-Item -LiteralPath $archivePath).Length
    Files = $seen.Count
}
