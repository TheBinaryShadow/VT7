[CmdletBinding()]
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactRoot = Join-Path $repositoryRoot 'artifacts'
$binaryRoot = Join-Path $artifactRoot 'vt7\bin\Release'
$packageRoot = [IO.Path]::GetFullPath((Join-Path $artifactRoot 'atlas-backend-proof-0.1'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts\atlas-backend-proof-0.1'))
$zipPath = Join-Path $artifactRoot 'VT7-atlas-backend-proof-0.1-x64.zip'
if (-not [string]::Equals($packageRoot, $expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected Atlas package path.' }
if (-not $SkipBuild) { & (Join-Path $PSScriptRoot 'Build-VT7.ps1') -Configuration Release }
& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -AtlasProofOnly

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installation = (& $vswhere -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
$redistVersion = [IO.File]::ReadAllText((Join-Path $installation 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt')).Trim()
if ($redistVersion -ne '14.44.35112') { throw "Expected pinned CRT 14.44.35112, found $redistVersion" }
$redistRoot = Join-Path $installation "VC\Redist\MSVC\$redistVersion\x64\Microsoft.VC143.CRT"
$proofSource = Join-Path $repositoryRoot 'src\vt7\VT7.AtlasProof'
$dependencyRoot = Join-Path $artifactRoot 'vt7\deps'
# Exact source/destination manifest, including licenses for linked backend code.
$manifest = @(
    @((Join-Path $binaryRoot 'VT7.AtlasProof.exe'), 'VT7.AtlasProof.exe'),
    @((Join-Path $binaryRoot 'VT7.AtlasProof.pdb'), 'symbols\VT7.AtlasProof.pdb'),
    @((Join-Path $redistRoot 'msvcp140.dll'), 'msvcp140.dll'),
    @((Join-Path $redistRoot 'vcruntime140.dll'), 'vcruntime140.dll'),
    @((Join-Path $redistRoot 'vcruntime140_1.dll'), 'vcruntime140_1.dll'),
    @((Join-Path $repositoryRoot 'LICENSE'), 'LICENSE.txt'),
    @((Join-Path $repositoryRoot 'NOTICE.md'), 'NOTICE.md'),
    @((Join-Path $repositoryRoot 'src\vt7\VT7.Renderer\README.md'), 'RENDERER-PROVENANCE.md'),
    @((Join-Path $dependencyRoot 'wil-b6ec76a2d9a609897f25a7fa0a0bdf4238e94e35\LICENSE'), 'licenses\WIL.txt'),
    @((Join-Path $dependencyRoot 'GSL-152d6eb989a1ecd23fe9c9cfb2fb8cfc7c0cd0c1\LICENSE'), 'licenses\GSL.txt'),
    @((Join-Path $dependencyRoot 'fmt-407c905e45ad75fc29bf0f9bb7c5c2fd3475976f\LICENSE'), 'licenses\fmt.txt'),
    @((Join-Path $repositoryRoot 'oss\chromium\LICENSE'), 'licenses\chromium.txt')
)
foreach ($file in @('README.txt', 'RUN-ATLAS-TESTS.cmd', 'RUN-ATLAS-HARDWARE.cmd', 'RUN-ATLAS-WARP.cmd', 'RUN-ATLAS-D2D-HARDWARE.cmd', 'RUN-ATLAS-D2D-WARP.cmd')) {
    $manifest += ,@((Join-Path $proofSource $file), $file)
}
# stb_rect_pack's full MIT/public-domain alternatives are preserved in NOTICE.md.
foreach ($entry in $manifest) { if (-not (Test-Path -LiteralPath $entry[0] -PathType Leaf)) { throw "Missing input: $($entry[0])" } }
if (Test-Path -LiteralPath $packageRoot) { Remove-Item -LiteralPath $packageRoot -Recurse -Force }
foreach ($entry in $manifest) {
    $destination = Join-Path $packageRoot $entry[1]
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
    Copy-Item -LiteralPath $entry[0] -Destination $destination
}
& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -AtlasProofOnly -BinaryDirectory $packageRoot
& (Join-Path $PSScriptRoot 'Test-VT7AtlasProof.ps1') -Configuration Release -BinaryDirectory $packageRoot
$hashLines = Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
    $relative = $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    "$($hash.Hash.ToLowerInvariant())  $relative"
}
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, [Text.UTF8Encoding]::new($false))
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Atlas proof archive: $zipPath"
