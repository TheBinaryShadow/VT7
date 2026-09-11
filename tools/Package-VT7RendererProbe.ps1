[CmdletBinding()]
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactRoot = Join-Path $repositoryRoot 'artifacts'
$binaryRoot = Join-Path $artifactRoot 'vt7\bin\Release'
$packageRoot = [IO.Path]::GetFullPath((Join-Path $artifactRoot 'renderer-probe-0.13'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts\renderer-probe-0.13'))
$zipPath = Join-Path $artifactRoot 'VT7-renderer-probe-0.13-x64.zip'
if (-not [string]::Equals($packageRoot, $expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected renderer package path.' }
if (-not $SkipBuild) { & (Join-Path $PSScriptRoot 'Build-VT7.ps1') -Configuration Release }
& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -RendererProbeOnly
& (Join-Path $PSScriptRoot 'Verify-VT7Fonts.ps1')

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installation = (& $vswhere -latest -products * -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
$redistVersion = [IO.File]::ReadAllText((Join-Path $installation 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt')).Trim()
if ($redistVersion -ne '14.44.35112') { throw "Expected pinned CRT 14.44.35112, found $redistVersion" }
$redistRoot = Join-Path $installation "VC\Redist\MSVC\$redistVersion\x64\Microsoft.VC143.CRT"
$probeSource = Join-Path $repositoryRoot 'src\vt7\VT7.RendererProbe'
$wilLicense = Join-Path $artifactRoot 'vt7\deps\wil-b6ec76a2d9a609897f25a7fa0a0bdf4238e94e35\LICENSE'
$sources = @(
    (Join-Path $binaryRoot 'VT7.RendererProbe.exe'),
    (Join-Path $binaryRoot 'VT7.RendererProbe.pdb'),
    (Join-Path $redistRoot 'msvcp140.dll'),
    (Join-Path $redistRoot 'vcruntime140.dll'),
    (Join-Path $redistRoot 'vcruntime140_1.dll'),
    (Join-Path $probeSource 'README.txt'),
    (Join-Path $probeSource 'RUN-RENDERER-PROBE.cmd'),
    (Join-Path $repositoryRoot 'LICENSE'),
    (Join-Path $repositoryRoot 'NOTICE.md'),
    $wilLicense
)
foreach ($source in $sources) { if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing package input: $source" } }
if (Test-Path -LiteralPath $packageRoot) { Remove-Item -LiteralPath $packageRoot -Recurse -Force }
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $packageRoot 'symbols') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $packageRoot 'licenses') -Force | Out-Null
foreach ($source in $sources[0..6]) {
    $destination = if ($source.EndsWith('.pdb')) { Join-Path $packageRoot 'symbols' } else { $packageRoot }
    Copy-Item -LiteralPath $source -Destination $destination
}
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'NOTICE.md') -Destination $packageRoot
Copy-Item -LiteralPath $wilLicense -Destination (Join-Path $packageRoot 'licenses\WIL.txt')
$coreLicenses = @(
    @('artifacts\vt7\deps\GSL-152d6eb989a1ecd23fe9c9cfb2fb8cfc7c0cd0c1\LICENSE', 'GSL.txt'),
    @('artifacts\vt7\deps\fmt-407c905e45ad75fc29bf0f9bb7c5c2fd3475976f\LICENSE', 'fmt.txt'),
    @('oss\chromium\LICENSE', 'chromium.txt'),
    @('src\vt7\VT7.Core\README.md', 'CORE-PROVENANCE.md')
)
foreach ($entry in $coreLicenses) {
    Copy-Item -LiteralPath (Join-Path $repositoryRoot $entry[0]) -Destination (Join-Path $packageRoot ('licenses\' + $entry[1]))
}

# The probe links TerminalCore for cell fixtures, never the unported AtlasEngine.
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'oss\unifont') -Destination (Join-Path $packageRoot 'fonts') -Recurse
& (Join-Path $PSScriptRoot 'Verify-VT7Fonts.ps1') -FontDirectory (Join-Path $packageRoot 'fonts')
& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -RendererProbeOnly -BinaryDirectory $packageRoot
& (Join-Path $PSScriptRoot 'Test-VT7RendererProbe.ps1') -Configuration Release -BinaryDirectory $packageRoot
$hashLines = Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
    $relative = $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    "$($hash.Hash.ToLowerInvariant())  $relative"
}
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, [Text.UTF8Encoding]::new($false))
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Renderer probe archive: $zipPath"
