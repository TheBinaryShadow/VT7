[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",

    [switch]$NoRestore
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$solutionPath = Join-Path $repositoryRoot "VT7.sln"
$vswherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path -LiteralPath $vswherePath -PathType Leaf)) {
    throw "Visual Studio Installer's vswhere.exe was not found at $vswherePath."
}

$installationPath = (& $vswherePath `
    -latest `
    -products * `
    -version "[17.0,18.0)" `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath).Trim()

if (-not $installationPath) {
    throw "Visual Studio 2022 with the x64/x86 C++ tools was not found."
}

$msbuildPath = Join-Path $installationPath "MSBuild\Current\Bin\MSBuild.exe"
$compilerPath = Join-Path $installationPath "VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe"
$sdkPath = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Include\10.0.26100.0"
$netFrameworkPath = Join-Path ${env:ProgramFiles(x86)} "Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8"

$requiredPaths = @(
    $msbuildPath,
    $compilerPath,
    $sdkPath,
    $netFrameworkPath
)

foreach ($requiredPath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required pinned build component was not found: $requiredPath"
    }
}

Write-Host "VT7 build toolchain"
Write-Host "  Visual Studio: $installationPath"
Write-Host "  MSVC:         14.44.35207"
Write-Host "  Windows SDK:  10.0.26100.0"
Write-Host "  .NET target:  .NET Framework 4.8"
Write-Host "  Configuration: $Configuration|x64"

$arguments = @(
    $solutionPath,
    "/m",
    "/p:Configuration=$Configuration",
    "/p:Platform=x64",
    "/p:UseMultiToolTask=true",
    "/p:MultiProcMaxCount=8",
    "/verbosity:minimal"
)

if (-not $NoRestore) {
    & (Join-Path $PSScriptRoot 'Restore-VT7Dependencies.ps1')
    $arguments += "/restore"
}

& $msbuildPath @arguments
if ($LASTEXITCODE -ne 0) {
    throw "VT7 build failed with exit code $LASTEXITCODE."
}

$binaryPath = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration"
Write-Host "VT7 build completed: $binaryPath"
