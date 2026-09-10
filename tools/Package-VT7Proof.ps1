[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$artifactRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts"))
$binaryRoot = Join-Path $artifactRoot "vt7\bin\Release"
$packageRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactRoot "viewport-proof"))
$zipPath = Join-Path $artifactRoot "VT7-viewport-proof-0.2.0-x64.zip"
$expectedPackageRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts\viewport-proof"))

if (-not [string]::Equals($packageRoot, $expectedPackageRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to package outside the expected VT7 artifact directory: $packageRoot"
}

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "Build-VT7.ps1") -Configuration Release
    if ($LASTEXITCODE -ne 0) {
        throw "The release build failed."
    }
}

& (Join-Path $PSScriptRoot "Verify-VT7.ps1") -Configuration Release
if ($LASTEXITCODE -ne 0) {
    throw "The release verification failed."
}

if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

$requiredBinaries = @(
    "VT7.Host.exe",
    "VT7.Host.exe.config",
    "VT7.Native.dll"
)

foreach ($fileName in $requiredBinaries) {
    $sourcePath = Join-Path $binaryRoot $fileName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required release file was not found: $sourcePath"
    }
    Copy-Item -LiteralPath $sourcePath -Destination $packageRoot
}

$vswherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
$installationPath = (& $vswherePath `
    -latest `
    -products * `
    -version "[17.0,18.0)" `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath).Trim()
$redistVersionPath = Join-Path $installationPath "VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt"
if (-not (Test-Path -LiteralPath $redistVersionPath -PathType Leaf)) {
    throw "Visual Studio's app-local runtime version marker was not found: $redistVersionPath"
}

$redistVersion = [System.IO.File]::ReadAllText($redistVersionPath).Trim()
if ($redistVersion -ne "14.44.35112") {
    throw "VT7 packaging requires Visual C++ runtime 14.44.35112. Found $redistVersion."
}

$redistRoot = Join-Path $installationPath "VC\Redist\MSVC\$redistVersion\x64\Microsoft.VC143.CRT"

if (-not (Test-Path -LiteralPath $redistRoot -PathType Container)) {
    throw "The pinned x64 Visual C++ app-local runtime was not found: $redistRoot"
}

$runtimeFiles = @(
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll"
)
foreach ($runtimeFile in $runtimeFiles) {
    $runtimePath = Join-Path $redistRoot $runtimeFile
    if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
        throw "Required app-local runtime file was not found: $runtimePath"
    }
    Copy-Item -LiteralPath $runtimePath -Destination $packageRoot
}

Copy-Item -LiteralPath (Join-Path $repositoryRoot "src\vt7\packaging\README.txt") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot "src\vt7\packaging\RUN-VT7.cmd") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot "src\vt7\packaging\RUN-DIAGNOSTICS.cmd") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot "src\vt7\packaging\RUN-VIEWPORT-TEST.cmd") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot "LICENSE") -Destination (Join-Path $packageRoot "LICENSE.txt")
Copy-Item -LiteralPath (Join-Path $repositoryRoot "NOTICE.md") -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot "src\vt7\VT7.Core\README.md") -Destination (Join-Path $packageRoot "CORE-PROVENANCE.md")

$licenseRoot = Join-Path $packageRoot 'licenses'
New-Item -ItemType Directory -Path $licenseRoot -Force | Out-Null
$dependencyRoot = Join-Path $artifactRoot 'vt7\deps'
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'wil-b6ec76a2d9a609897f25a7fa0a0bdf4238e94e35\LICENSE') -Destination (Join-Path $licenseRoot 'WIL.txt')
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'GSL-152d6eb989a1ecd23fe9c9cfb2fb8cfc7c0cd0c1\LICENSE') -Destination (Join-Path $licenseRoot 'GSL.txt')
Copy-Item -LiteralPath (Join-Path $dependencyRoot 'fmt-407c905e45ad75fc29bf0f9bb7c5c2fd3475976f\LICENSE') -Destination (Join-Path $licenseRoot 'fmt.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'oss\chromium\LICENSE') -Destination (Join-Path $licenseRoot 'chromium.txt')

# Test the assembled files, including the app-local runtime, before creating an archive.
& (Join-Path $PSScriptRoot 'Test-VT7.ps1') -Configuration Release -BinaryDirectory $packageRoot

$symbolRoot = Join-Path $packageRoot "symbols"
New-Item -ItemType Directory -Path $symbolRoot -Force | Out-Null
Get-ChildItem -LiteralPath $binaryRoot -Filter "*.pdb" -File |
    Copy-Item -Destination $symbolRoot

$hashLines = Get-ChildItem -LiteralPath $packageRoot -File -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
        $relativePath = $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
        "$($hash.Hash.ToLowerInvariant())  $relativePath"
    }
[System.IO.File]::WriteAllLines(
    (Join-Path $packageRoot "SHA256SUMS.txt"),
    $hashLines,
    [System.Text.UTF8Encoding]::new($false))

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "VT7 proof package: $packageRoot"
Write-Host "VT7 proof archive: $zipPath"
