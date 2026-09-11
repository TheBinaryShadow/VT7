[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",
    [string]$BinaryDirectory,
    [switch]$RendererProbeOnly,
    [switch]$AtlasProofOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$binaryRoot = if ($BinaryDirectory) { [IO.Path]::GetFullPath($BinaryDirectory) } else { Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration" }
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration"
$hostPath = Join-Path $binaryRoot "VT7.Host.exe"
$nativePath = Join-Path $binaryRoot "VT7.Native.dll"
$rendererProbePath = Join-Path $binaryRoot "VT7.RendererProbe.exe"
$atlasProofPath = Join-Path $binaryRoot "VT7.AtlasProof.exe"
$vswherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

if ($RendererProbeOnly -and $AtlasProofOnly) { throw 'Select only one standalone verification target.' }
$requiredImages = if ($AtlasProofOnly) { @($atlasProofPath) } elseif ($RendererProbeOnly) { @($rendererProbePath) } else { @($hostPath, $nativePath) }
foreach ($binaryPath in $requiredImages) {
    if (-not (Test-Path -LiteralPath $binaryPath -PathType Leaf)) {
        throw "VT7 binary was not found: $binaryPath. Run tools\Build-VT7.ps1 first."
    }
}

$installationPath = (& $vswherePath `
    -latest `
    -products * `
    -version "[17.0,18.0)" `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath).Trim()
$dumpbinPath = Join-Path $installationPath "VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\dumpbin.exe"

if (-not (Test-Path -LiteralPath $dumpbinPath -PathType Leaf)) {
    throw "Pinned dumpbin.exe was not found: $dumpbinPath"
}

New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

$textExtensions = @(
    ".cmd", ".cpp", ".cs", ".csproj", ".def", ".gitignore", ".h", ".hpp", ".json", ".manifest", ".md",
    ".props", ".ps1", ".sln", ".targets", ".txt", ".vcxproj", ".xaml",
    ".xml", ".yaml", ".yml"
)
$dash = [char]0x2014
$dashFiles = New-Object System.Collections.Generic.List[string]
$repositoryFiles = & git -C $repositoryRoot ls-files --cached --others --exclude-standard

foreach ($relativePath in $repositoryFiles) {
    $extension = [System.IO.Path]::GetExtension($relativePath).ToLowerInvariant()
    $fileName = [System.IO.Path]::GetFileName($relativePath)
    if ($textExtensions -notcontains $extension -and $fileName -ne ".gitignore") {
        continue
    }

    $fullPath = Join-Path $repositoryRoot $relativePath
    if ((Test-Path -LiteralPath $fullPath -PathType Leaf) -and
        [System.IO.File]::ReadAllText($fullPath).Contains($dash)) {
        $dashFiles.Add($relativePath)
    }
}

if ($dashFiles.Count -gt 0) {
    throw "The project punctuation rule failed in: $($dashFiles -join ', ')"
}

$forbiddenImports = @(
    "ClosePseudoConsole",
    "CreateDXGIFactory2",
    "CreatePseudoConsole",
    "DCompositionCreateDevice",
    "DXGIGetDebugInterface1",
    "GetDpiForWindow",
    "ResizePseudoConsole",
    "SetThreadDescription",
    "WaitOnAddress",
    "WakeByAddress",
    "dcomp.dll",
    "icu.dll",
    "icuuc.dll",
    "RoInitialize",
    "RoGetActivationFactory",
    "WindowsCreateString",
    "windows.ui.xaml.dll"
)

function Assert-VT7Binary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $name = [System.IO.Path]::GetFileName($Path)
    $headers = (& $dumpbinPath /nologo /headers $Path | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "dumpbin headers failed for $Path" }
    $imports = (& $dumpbinPath /nologo /imports $Path | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "dumpbin imports failed for $Path" }

    [System.IO.File]::WriteAllText(
        (Join-Path $reportRoot "$name.headers.txt"),
        $headers,
        [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText(
        (Join-Path $reportRoot "$name.imports.txt"),
        $imports,
        [System.Text.UTF8Encoding]::new($false))

    if ($headers -notmatch "(?im)^\s*8664 machine \(x64\)") {
        throw "$name is not an x64 image."
    }

    foreach ($label in @("operating system version", "subsystem version")) {
        $match = [regex]::Match($headers, "(?im)^\s*(\d+)\.(\d+)\s+$([regex]::Escape($label))")
        if (-not $match.Success) {
            throw "$name does not expose a readable $label in its PE headers."
        }

        $major = [int]$match.Groups[1].Value
        $minor = [int]$match.Groups[2].Value
        if ($major -gt 6 -or ($major -eq 6 -and $minor -gt 1)) {
            throw "$name declares post-Windows 7 $label $major.$minor."
        }
    }

    foreach ($forbiddenImport in $forbiddenImports) {
        if ($imports.IndexOf($forbiddenImport, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "$name imports post-Windows 7 dependency: $forbiddenImport"
        }
    }

    if ($imports -match "(?im)^\s*(api-ms-win-core-winrt|ext-ms-win-)") {
        throw "$name imports a post-Windows 7 API-set dependency."
    }

    Write-Host "Verified $name"
}

foreach ($binaryPath in $requiredImages) { Assert-VT7Binary -Path $binaryPath }
if (-not $RendererProbeOnly -and -not $AtlasProofOnly -and (Test-Path -LiteralPath $rendererProbePath)) {
    Assert-VT7Binary -Path $rendererProbePath
}
if (-not $RendererProbeOnly -and -not $AtlasProofOnly -and (Test-Path -LiteralPath $atlasProofPath)) {
    Assert-VT7Binary -Path $atlasProofPath
}

if ($BinaryDirectory) {
    if ($Configuration -eq 'Release') {
        foreach ($runtime in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
            if (-not (Test-Path -LiteralPath (Join-Path $binaryRoot $runtime) -PathType Leaf)) {
                throw "Assembled Release package is missing app-local runtime: $runtime"
            }
        }
    }
    # Audit every native image in an assembled package, not just its entrypoint.
    foreach ($image in Get-ChildItem -LiteralPath $binaryRoot -File -Recurse) {
        if ($image.Extension -in @('.dll', '.exe') -and $requiredImages -notcontains $image.FullName) {
            Assert-VT7Binary -Path $image.FullName
        }
    }
}
elseif ($Configuration -eq "Release") {
    $redistVersionPath = Join-Path $installationPath "VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt"
    if (-not (Test-Path -LiteralPath $redistVersionPath -PathType Leaf)) {
        throw "Visual Studio's app-local runtime version marker was not found: $redistVersionPath"
    }

    $redistVersion = [System.IO.File]::ReadAllText($redistVersionPath).Trim()
    if ($redistVersion -ne "14.44.35112") {
        throw "VT7 verification requires Visual C++ runtime 14.44.35112. Found $redistVersion."
    }

    $redistRoot = Join-Path $installationPath "VC\Redist\MSVC\$redistVersion\x64\Microsoft.VC143.CRT"
    Assert-VT7Binary -Path (Join-Path $redistRoot "vcruntime140.dll")
    Assert-VT7Binary -Path (Join-Path $redistRoot "vcruntime140_1.dll")
    Assert-VT7Binary -Path (Join-Path $redistRoot "msvcp140.dll")
}

Write-Host "VT7 verification passed. Reports: $reportRoot"
