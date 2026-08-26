[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$binaryRoot = Join-Path $repositoryRoot "artifacts\vt7\bin\$Configuration"
$reportRoot = Join-Path $repositoryRoot "artifacts\vt7\reports\$Configuration"
$hostPath = Join-Path $binaryRoot "VT7.Host.exe"
$nativePath = Join-Path $binaryRoot "VT7.Native.dll"
$vswherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

foreach ($binaryPath in @($hostPath, $nativePath)) {
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
    ".cmd", ".cpp", ".cs", ".def", ".gitignore", ".h", ".json", ".md",
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
    "GetDpiForWindow",
    "ResizePseudoConsole",
    "SetThreadDescription",
    "WaitOnAddress",
    "WakeByAddress",
    "dcomp.dll",
    "windows.ui.xaml.dll"
)

function Assert-VT7Binary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $name = [System.IO.Path]::GetFileName($Path)
    $headers = (& $dumpbinPath /nologo /headers $Path | Out-String)
    $imports = (& $dumpbinPath /nologo /imports $Path | Out-String)

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

Assert-VT7Binary -Path $hostPath
Assert-VT7Binary -Path $nativePath

if ($Configuration -eq "Release") {
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
}

Write-Host "VT7 verification passed. Reports: $reportRoot"
