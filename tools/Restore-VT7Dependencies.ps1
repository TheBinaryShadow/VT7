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
Write-Host 'VT7 source dependencies verified.'
