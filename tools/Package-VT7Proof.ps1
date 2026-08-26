[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$artifactRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts"))
$binaryRoot = Join-Path $artifactRoot "vt7\bin\Release"
$packageRoot = [System.IO.Path]::GetFullPath((Join-Path $artifactRoot "proof-of-life"))
$zipPath = Join-Path $artifactRoot "VT7-proof-of-life-x64.zip"
$expectedPackageRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts\proof-of-life"))

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
Copy-Item -LiteralPath (Join-Path $repositoryRoot "LICENSE") -Destination (Join-Path $packageRoot "LICENSE.txt")

$symbolRoot = Join-Path $packageRoot "symbols"
New-Item -ItemType Directory -Path $symbolRoot -Force | Out-Null
Get-ChildItem -LiteralPath $binaryRoot -Filter "*.pdb" -File |
    Copy-Item -Destination $symbolRoot

$hashLines = Get-ChildItem -LiteralPath $packageRoot -File |
    Sort-Object Name |
    ForEach-Object {
        $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
        "$($hash.Hash.ToLowerInvariant())  $($_.Name)"
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
