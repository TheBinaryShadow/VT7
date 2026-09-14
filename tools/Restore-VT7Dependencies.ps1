[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$dependencyRoot = Join-Path $repositoryRoot 'artifacts\vt7\deps'
New-Item -ItemType Directory -Path $dependencyRoot -Force | Out-Null

# Immutable source revisions with archive hashes. No package install scripts run.
$dependencies = @(
    @{ Name = 'wil'; Repository = 'microsoft/wil'; Revision = 'b6ec76a2d9a609897f25a7fa0a0bdf4238e94e35'; Sha256 = '51d603b207b207ebc8f464144f60593c33d1ef0fc69cb5959697351aea18ace8'; Header = 'include\wil\resource.h' },
    @{ Name = 'GSL'; Repository = 'microsoft/GSL'; Revision = '152d6eb989a1ecd23fe9c9cfb2fb8cfc7c0cd0c1'; Sha256 = '6565f61db79e10445f831f92d9021aaea5115810f0c3c63cfcd278b22dac37fc'; Header = 'include\gsl\gsl' },
    @{ Name = 'fmt'; Repository = 'fmtlib/fmt'; Revision = '407c905e45ad75fc29bf0f9bb7c5c2fd3475976f'; Sha256 = '0470bba08d31fc470a247d03a2c278000adce19502741fdc28b39c9cad2bda57'; Header = 'include\fmt\format.h' }
)

foreach ($dependency in $dependencies) {
    $archivePath = Join-Path $dependencyRoot ($dependency.Name + '.zip')
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        $url = 'https://codeload.github.com/' + $dependency.Repository + '/zip/' + $dependency.Revision
        Write-Host ('Restoring ' + $dependency.Name + ' from ' + $dependency.Revision)
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archivePath
    }
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    if ($actualHash -ne $dependency.Sha256) {
        throw ('Dependency archive hash mismatch: ' + $archivePath)
    }
    $sourceRoot = Join-Path $dependencyRoot ($dependency.Name + '-' + $dependency.Revision)
    # Re-extract the verified archive to avoid trusting stale extracted headers.
    Expand-Archive -LiteralPath $archivePath -DestinationPath $dependencyRoot -Force
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $dependency.Header))) {
        throw ('Dependency archive is missing its expected header: ' + $dependency.Name)
    }
}

# P01 uses the official native-only MSVC release bundle. The WinPTY command
# adapter is intentionally not staged; VT7 exercises winpty.dll and its agent.
$winPtyArchive = Join-Path $dependencyRoot 'winpty-0.4.3-msvc2015.zip'
$winPtyArchiveHash = '35A48ECE2FF4ACDCBC8299D4920DE53EB86B1FB41E64D2FE5AE7898931BCEE89'
if (-not (Test-Path -LiteralPath $winPtyArchive -PathType Leaf)) {
    Write-Host 'Restoring WinPTY 0.4.3 official MSVC 2015 bundle'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/rprichard/winpty/releases/download/0.4.3/winpty-0.4.3-msvc2015.zip' -OutFile $winPtyArchive
}
if ((Get-FileHash -LiteralPath $winPtyArchive -Algorithm SHA256).Hash -ne $winPtyArchiveHash) {
    throw ('Dependency archive hash mismatch: ' + $winPtyArchive)
}

$winPtyRoot = [IO.Path]::GetFullPath((Join-Path $dependencyRoot 'winpty-0.4.3-msvc2015'))
$dependencyBoundary = [IO.Path]::GetFullPath($dependencyRoot) + [IO.Path]::DirectorySeparatorChar
if (-not $winPtyRoot.StartsWith($dependencyBoundary, [StringComparison]::OrdinalIgnoreCase)) {
    throw ('Refusing to replace a dependency outside the VT7 cache: ' + $winPtyRoot)
}
if (Test-Path -LiteralPath $winPtyRoot) {
    Remove-Item -LiteralPath $winPtyRoot -Recurse -Force
}
Expand-Archive -LiteralPath $winPtyArchive -DestinationPath $winPtyRoot

$winPtyFiles = @(
    @{ Path = 'x64\bin\winpty.dll'; Sha256 = '936F611C2129600D35AB7AAD45546A837F4F3A9CA7F673E5D66B48C313B9CD75' },
    @{ Path = 'x64\bin\winpty-agent.exe'; Sha256 = '9ADD1A61155EC47CF6F347FAF776B746EEBBDE1DC9360D81B8A909DA34650642' },
    @{ Path = 'x64\lib\winpty.lib'; Sha256 = '32C9D811A34E0080D52100084770D248680E02D91F025781E32EC5CB149C07CB' },
    @{ Path = 'include\winpty.h'; Sha256 = '35AC2BD9561F26B8CC9324AA9F1BE500FF4A7B13C2B66CF65C3499F559D7B4E7' },
    @{ Path = 'include\winpty_constants.h'; Sha256 = '2720B82DB1487ED9276B760C322207B7F1E9D1C4B62994F9F8431EE7C3D8424A' },
    @{ Path = 'LICENSE'; Sha256 = 'C39E428064B4F3E4FE81A975BF0FD3B845922B431BC4D9A7FFC8BFB091981836' }
)
foreach ($file in $winPtyFiles) {
    $path = Join-Path $winPtyRoot $file.Path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('WinPTY bundle is missing: ' + $file.Path)
    }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.Sha256) {
        throw ('WinPTY file hash mismatch: ' + $file.Path)
    }
}
Write-Host 'VT7 dependencies verified.'
