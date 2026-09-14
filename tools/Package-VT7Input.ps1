[CmdletBinding()]
param(
    [string]$PackageName = 'VT7-Input-I01-0.2-x64',
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = Join-Path $repositoryRoot 'artifacts\vt7\bin\Release'
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')

if ($PackageName -notmatch '^VT7-Input-I01-[0-9.]+-x64$') { throw "Invalid I01 package name: $PackageName" }
$payloadVersion = [regex]::Match($PackageName, '^VT7-Input-I01-([0-9.]+)-x64$').Groups[1].Value
foreach ($path in @($packageRoot, $archivePath)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to replace an existing I01 package: $path" }
}
if (-not $NoBuild) { & (Join-Path $PSScriptRoot 'Build-VT7.ps1') -Configuration Release }

$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installationPath = (& $vswherePath -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
if (-not $installationPath) { throw 'Visual Studio 2022 C++ tools were not found.' }
$redistVersionPath = Join-Path $installationPath 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt'
$redistVersion = [IO.File]::ReadAllText($redistVersionPath).Trim()
if ($redistVersion -ne '14.44.35112') { throw "Unexpected Visual C++ runtime version: $redistVersion" }
$redistRoot = Join-Path $installationPath "VC\Redist\MSVC\$redistVersion\x64\Microsoft.VC143.CRT"

$inputs = [ordered]@{
    'VT7.InputProbe.exe' = Join-Path $binaryRoot 'VT7.InputProbe.exe'
    'VT7.InputFocusProbe.exe' = Join-Path $binaryRoot 'VT7.InputFocusProbe.exe'
    'VT7.InputFocusProbe.exe.config' = Join-Path $binaryRoot 'VT7.InputFocusProbe.exe.config'
    'Test-VT7Input.ps1' = Join-Path $PSScriptRoot 'Test-VT7Input.ps1'
    'RUN-INPUT-I01.cmd' = Join-Path $repositoryRoot 'src\vt7\VT7.InputProbe\RUN-INPUT-I01.cmd'
    'README.txt' = Join-Path $repositoryRoot 'src\vt7\VT7.InputProbe\README.txt'
    'LICENSE.txt' = Join-Path $repositoryRoot 'LICENSE'
    'NOTICE.md' = Join-Path $repositoryRoot 'NOTICE.md'
    'msvcp140.dll' = Join-Path $redistRoot 'msvcp140.dll'
    'vcruntime140.dll' = Join-Path $redistRoot 'vcruntime140.dll'
    'vcruntime140_1.dll' = Join-Path $redistRoot 'vcruntime140_1.dll'
}
foreach ($source in $inputs.Values) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "I01 package input is missing: $source" }
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
foreach ($name in $inputs.Keys) { Copy-Item -LiteralPath $inputs[$name] -Destination (Join-Path $packageRoot $name) }
& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -BinaryDirectory $packageRoot -InputProbeOnly

$head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
$manifest = [ordered]@{
    schema = 'vt7-i01-package-v1'
    package = $PackageName
    createdUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    diagnosticPayload = $payloadVersion
    sourceGitHead = $head
    sourceGitDirty = ($status.Count -gt 0)
    scope = 'I01 Croatian HR Latin ToUnicodeEx, TerminalInput, WPF/native focus, Ctrl and resize characterization'
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)

$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -File | Sort-Object Name | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.Name
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)

Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Path $packageParent -Force | Out-Null
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)

$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -File) { $expected[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name) -or $entry.FullName -ne $entry.Name) { throw "Unexpected I01 ZIP entry: $($entry.FullName)" }
        if ($seen.ContainsKey($entry.Name) -or -not $expected.ContainsKey($entry.Name)) { throw "Duplicate or unknown I01 ZIP entry: $($entry.Name)" }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$entry.Name]) { throw "I01 ZIP entry hash mismatch: $($entry.Name)" }
        $seen[$entry.Name] = $true
    }
}
finally { $archive.Dispose() }
if ($seen.Count -ne $expected.Count) { throw 'I01 ZIP is missing one or more staged files.' }

[pscustomobject]@{
    PackageDirectory = $packageRoot
    ArchivePath = $archivePath
    ArchiveSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    Bytes = (Get-Item -LiteralPath $archivePath).Length
    Files = $seen.Count
}
