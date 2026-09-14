[CmdletBinding()]
param(
    [string]$PackageName = 'VT7-WinPTY-P01-0.4-x64',
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = Join-Path $repositoryRoot 'artifacts\vt7\bin\Release'
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')

if ($PackageName -notmatch '^VT7-WinPTY-P01-[0-9.]+-x64$') {
    throw "Invalid P01 package name: $PackageName"
}
foreach ($path in @($packageRoot, $archivePath)) {
    if (Test-Path -LiteralPath $path) {
        throw "Refusing to replace an existing P01 package: $path"
    }
}

if (-not $NoBuild) {
    & (Join-Path $PSScriptRoot 'Build-VT7.ps1') -Configuration Release
}

$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installationPath = (& $vswherePath -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
if (-not $installationPath) { throw 'Visual Studio 2022 C++ tools were not found.' }
$redistVersionPath = Join-Path $installationPath 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt'
$redistVersion = [IO.File]::ReadAllText($redistVersionPath).Trim()
if ($redistVersion -ne '14.44.35112') { throw "Unexpected Visual C++ runtime version: $redistVersion" }
$redistRoot = Join-Path $installationPath "VC\Redist\MSVC\$redistVersion\x64\Microsoft.VC143.CRT"

$inputs = [ordered]@{
    'VT7.WinPtyProbe.exe' = Join-Path $binaryRoot 'VT7.WinPtyProbe.exe'
    'VT7.WinPtyFixture.exe' = Join-Path $binaryRoot 'VT7.WinPtyFixture.exe'
    'winpty.dll' = Join-Path $binaryRoot 'winpty.dll'
    'winpty-agent.exe' = Join-Path $binaryRoot 'winpty-agent.exe'
    'winpty-LICENSE.txt' = Join-Path $binaryRoot 'winpty-LICENSE.txt'
    'Test-VT7WinPty.ps1' = Join-Path $PSScriptRoot 'Test-VT7WinPty.ps1'
    'RUN-WINPTY-P01.cmd' = Join-Path $repositoryRoot 'src\vt7\VT7.WinPtyProbe\RUN-WINPTY-P01.cmd'
    'README.txt' = Join-Path $repositoryRoot 'src\vt7\VT7.WinPtyProbe\README.txt'
    'LICENSE.txt' = Join-Path $repositoryRoot 'LICENSE'
    'NOTICE.md' = Join-Path $repositoryRoot 'NOTICE.md'
    'msvcp140.dll' = Join-Path $redistRoot 'msvcp140.dll'
    'vcruntime140.dll' = Join-Path $redistRoot 'vcruntime140.dll'
    'vcruntime140_1.dll' = Join-Path $redistRoot 'vcruntime140_1.dll'
}
foreach ($source in $inputs.Values) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "P01 package input is missing: $source"
    }
}

$runtimeHashes = @{
    'winpty.dll' = '936F611C2129600D35AB7AAD45546A837F4F3A9CA7F673E5D66B48C313B9CD75'
    'winpty-agent.exe' = '9ADD1A61155EC47CF6F347FAF776B746EEBBDE1DC9360D81B8A909DA34650642'
    'winpty-LICENSE.txt' = 'C39E428064B4F3E4FE81A975BF0FD3B845922B431BC4D9A7FFC8BFB091981836'
}
foreach ($name in $runtimeHashes.Keys) {
    if ((Get-FileHash -LiteralPath $inputs[$name] -Algorithm SHA256).Hash -ne $runtimeHashes[$name]) {
        throw "P01 package dependency hash mismatch: $name"
    }
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
foreach ($name in $inputs.Keys) {
    Copy-Item -LiteralPath $inputs[$name] -Destination (Join-Path $packageRoot $name)
}

& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -BinaryDirectory $packageRoot -WinPtyProbeOnly

$head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
$manifest = [ordered]@{
    schema = 'vt7-p01-package-v1'
    package = $PackageName
    createdUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    diagnosticPayload = '0.2'
    sourceGitHead = $head
    sourceGitDirty = ($status.Count -gt 0)
    winpty = [ordered]@{
        version = '0.4.3'
        commit = '3e1ab962d5262dd76159870c6dc0724927ca6a9d'
        releaseArchiveSha256 = '35A48ECE2FF4ACDCBC8299D4920DE53EB86B1FB41E64D2FE5AE7898931BCEE89'
        dllSha256 = $runtimeHashes['winpty.dll']
        agentSha256 = $runtimeHashes['winpty-agent.exe']
        licenseSha256 = $runtimeHashes['winpty-LICENSE.txt']
    }
    scope = 'P01 controlled local-console fidelity characterization; no production session selection'
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 8), $utf8)

$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -File | Sort-Object Name | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.Name
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)

Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Path $packageParent -Force | Out-Null
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)

$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -File) {
    $expected[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name) -or $entry.FullName -ne $entry.Name) {
            throw "Unexpected P01 ZIP entry: $($entry.FullName)"
        }
        if ($seen.ContainsKey($entry.Name) -or -not $expected.ContainsKey($entry.Name)) {
            throw "Duplicate or unknown P01 ZIP entry: $($entry.Name)"
        }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '')
        }
        finally {
            $sha.Dispose()
            $stream.Dispose()
        }
        if ($hash -ne $expected[$entry.Name]) {
            throw "P01 ZIP entry hash mismatch: $($entry.Name)"
        }
        $seen[$entry.Name] = $true
    }
}
finally {
    $archive.Dispose()
}
if ($seen.Count -ne $expected.Count) {
    throw 'P01 ZIP is missing one or more staged files.'
}

[pscustomobject]@{
    PackageDirectory = $packageRoot
    ArchivePath = $archivePath
    ArchiveSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    Bytes = (Get-Item -LiteralPath $archivePath).Length
    Files = $seen.Count
}
