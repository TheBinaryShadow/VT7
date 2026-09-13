[CmdletBinding()]
param(
    [string]$BuildDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactRoot = Join-Path $repositoryRoot 'artifacts'
$issuedRoot = Join-Path $artifactRoot 'atlas-viewport-0.3.5'
$packageRoot = Join-Path $artifactRoot 'resource-lifetime-0.2'
$zipPath = Join-Path $artifactRoot 'VT7-resource-lifetime-0.2-x64.zip'
$expectedNativeHash = '0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49'
$expectedIssuedManifestHash = '633D0C890D8F3EF64531AF8A067F556663B2B3F2C56CD2B1362F8106464FA2EA'
$expectedIssuedArchiveHash = '57B2EE43BB9A1AC6AB227B7C7BE4E3FCB88C765753FDEDD988E14EF375604C86'

# Existing or partial candidates are evidence. Never remove or replace them.
foreach ($outputPath in @($packageRoot, $zipPath)) {
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to replace an existing package or archive: $outputPath. Preserve it and assign a new candidate identity before packaging again."
    }
}
function Assert-FileHash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file is missing: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) { throw "SHA256 mismatch for $Path. Expected $Expected; found $actual." }
}

$issuedManifestPath = Join-Path $issuedRoot 'SHA256SUMS.txt'
Assert-FileHash $issuedManifestPath $expectedIssuedManifestHash
Assert-FileHash (Join-Path $issuedRoot 'VT7.Native.dll') $expectedNativeHash
$issuedHashes = @{}
foreach ($line in [IO.File]::ReadAllLines($issuedManifestPath)) {
    if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Malformed issued checksum entry: $line" }
    $relativePath = $Matches[2]
    if ([IO.Path]::IsPathRooted($relativePath) -or $relativePath -match '(^|[\\/])\.\.([\\/]|$)' -or $issuedHashes.ContainsKey($relativePath)) {
        throw "Invalid or duplicate issued checksum path: $relativePath"
    }
    $issuedHashes[$relativePath] = $Matches[1].ToUpperInvariant()
}
$issuedFiles = @(
    'VT7.Native.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll',
    'LICENSE.txt', 'NOTICE.md', 'CORE-PROVENANCE.md', 'RENDERER-PROVENANCE.md'
)
foreach ($directoryName in @('fonts', 'licenses')) {
    $directoryPath = Join-Path $issuedRoot $directoryName
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) { throw "Required issued directory is missing: $directoryPath" }
    $directoryFiles = @(Get-ChildItem -LiteralPath $directoryPath -File -Recurse)
    if ($directoryFiles.Count -eq 0) { throw "Required issued directory is empty: $directoryPath" }
    foreach ($file in $directoryFiles) {
        $issuedFiles += $file.FullName.Substring($issuedRoot.Length + 1).Replace('\', '/')
    }
    foreach ($manifestPath in $issuedHashes.Keys) {
        if ($manifestPath.StartsWith($directoryName + '/', [StringComparison]::OrdinalIgnoreCase) -and $issuedFiles -notcontains $manifestPath) {
            throw "Required issued payload file is missing: $manifestPath"
        }
    }
}
$issuedFiles = @($issuedFiles | Sort-Object)
foreach ($relativePath in $issuedFiles) {
    if (-not $issuedHashes.ContainsKey($relativePath)) { throw "Issued payload file is absent from its original manifest: $relativePath" }
    Assert-FileHash (Join-Path $issuedRoot $relativePath) $issuedHashes[$relativePath]
}
$packagingFiles = @(
    'src/vt7/VT7.ResourceLifetime/RUN-RESOURCE-LIFETIME.cmd',
    'src/vt7/VT7.ResourceLifetime/Run-ResourceLifetime.ps1',
    'src/vt7/VT7.ResourceLifetime/README.txt',
    'tools/Package-VT7ResourceLifetime.ps1',
    'tools/Test-VT7ResourceLifetime.ps1'
)
foreach ($relativePath in $packagingFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
        throw "Required diagnostic packaging source is missing: $relativePath"
    }
}
if (-not $BuildDirectory) {
    $build = & (Join-Path $PSScriptRoot 'Build-VT7ResourceLifetime.ps1')
    $BuildDirectory = $build.OutputDirectory
}
$buildRoot = [IO.Path]::GetFullPath($BuildDirectory)
$buildManifestPath = Join-Path $buildRoot 'BUILD-MANIFEST.json'
if (-not (Test-Path -LiteralPath $buildManifestPath -PathType Leaf)) { throw "Completed diagnostic build manifest is missing: $buildManifestPath" }
$buildManifest = [IO.File]::ReadAllText($buildManifestPath) | ConvertFrom-Json
if ($buildManifest.Diagnostic -ne 'VT7.ResourceLifetime' -or $buildManifest.DiagnosticVersion -ne '0.2' -or
    $buildManifest.BuildStatus -ne 'Completed' -or $buildManifest.Configuration -ne 'Release' -or
    $buildManifest.Architecture -ne 'x64' -or $buildManifest.MSVCToolset -ne '14.44.35207' -or
    $buildManifest.WindowsSDK -ne '10.0.26100.0' -or $buildManifest.Runtime -ne 'Static release CRT (/MT)') {
    throw 'The selected build does not identify a completed, pinned Release x64 resource lifetime 0.2 diagnostic.'
}
Assert-FileHash (Join-Path $buildRoot 'VT7.ResourceLifetime.exe') $buildManifest.ExecutableSHA256
Assert-FileHash (Join-Path $buildRoot 'VT7.ResourceLifetime.pdb') $buildManifest.SymbolSHA256
$expectedBuildSources = @(
    'src/vt7/VT7.ResourceLifetime/resource-lifetime.cpp',
    'src/vt7/VT7.Native/include/vt7_native.h',
    'tools/Build-VT7ResourceLifetime.ps1'
)
if (@($buildManifest.SourceFiles).Count -ne $expectedBuildSources.Count) { throw 'Unexpected diagnostic build source inventory.' }
foreach ($relativePath in $expectedBuildSources) {
    $sourceEntry = @($buildManifest.SourceFiles | Where-Object { $_.Path -eq $relativePath })
    if ($sourceEntry.Count -ne 1) { throw "Missing or duplicate diagnostic source identity: $relativePath" }
    Assert-FileHash (Join-Path (Join-Path $buildRoot 'source') $relativePath) $sourceEntry[0].SHA256
}
$packageHead = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not read the packaging Git HEAD.' }
$packageStatus = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Could not read the packaging Git status.' }

New-Item -ItemType Directory -Path $packageRoot | Out-Null
foreach ($relativePath in $issuedFiles) {
    $destinationPath = Join-Path $packageRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $issuedRoot $relativePath) -Destination $destinationPath
    Assert-FileHash $destinationPath $issuedHashes[$relativePath]
}
Copy-Item -LiteralPath (Join-Path $buildRoot 'VT7.ResourceLifetime.exe') -Destination $packageRoot
Assert-FileHash (Join-Path $packageRoot 'VT7.ResourceLifetime.exe') $buildManifest.ExecutableSHA256
$symbolRoot = Join-Path $packageRoot 'symbols'
New-Item -ItemType Directory -Path $symbolRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $buildRoot 'VT7.ResourceLifetime.pdb') -Destination $symbolRoot
Assert-FileHash (Join-Path $symbolRoot 'VT7.ResourceLifetime.pdb') $buildManifest.SymbolSHA256
$provenanceRoot = Join-Path $packageRoot 'provenance'
$sourceRoot = Join-Path $provenanceRoot 'source'
New-Item -ItemType Directory -Path $provenanceRoot | Out-Null
Copy-Item -LiteralPath $issuedManifestPath -Destination (Join-Path $provenanceRoot 'issued-0.3.5-SHA256SUMS.txt')
Copy-Item -LiteralPath $buildManifestPath -Destination $provenanceRoot
foreach ($fileName in @('BUILD-INPUTS.json', 'build.log', 'compiler.rsp')) {
    Copy-Item -LiteralPath (Join-Path $buildRoot $fileName) -Destination $provenanceRoot
}
foreach ($sourceEntry in $buildManifest.SourceFiles) {
    $destinationPath = Join-Path $sourceRoot $sourceEntry.Path
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path (Join-Path $buildRoot 'source') $sourceEntry.Path) -Destination $destinationPath
    Assert-FileHash $destinationPath $sourceEntry.SHA256
}
$packagingSourceHashes = @()
foreach ($relativePath in $packagingFiles) {
    $originalPath = Join-Path $repositoryRoot $relativePath
    $hash = (Get-FileHash -LiteralPath $originalPath -Algorithm SHA256).Hash
    $destinationPath = Join-Path $sourceRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
    Copy-Item -LiteralPath $originalPath -Destination $destinationPath
    Assert-FileHash $destinationPath $hash
    $packagingSourceHashes += [ordered]@{ Path = $relativePath; SHA256 = $hash }
    if ($relativePath.StartsWith('src/vt7/VT7.ResourceLifetime/')) {
        Copy-Item -LiteralPath $destinationPath -Destination $packageRoot
        Assert-FileHash (Join-Path $packageRoot (Split-Path -Leaf $destinationPath)) $hash
    }
}
$manifest = [ordered]@{
    Package = 'VT7 resource lifetime comparison'
    PackageVersion = '0.2'
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    Purpose = 'Separate recreate-versus-reuse measurement. Completion is not resource-growth acceptance.'
    Diagnostic = [ordered]@{
        Executable = 'VT7.ResourceLifetime.exe'
        SHA256 = $buildManifest.ExecutableSHA256
        SourceGitHead = $buildManifest.SourceGitHead
        SourceGitDirty = $buildManifest.SourceGitDirty
        BuildManifest = 'provenance/BUILD-MANIFEST.json'
        Runtime = $buildManifest.Runtime
        MSVCToolset = $buildManifest.MSVCToolset
        WindowsSDK = $buildManifest.WindowsSDK
    }
    IssuedPayload = [ordered]@{
        Package = 'VT7-atlas-viewport-0.3.5-x64.zip'
        OriginalArchiveSHA256 = $expectedIssuedArchiveHash
        OriginalManifestSHA256 = $expectedIssuedManifestHash
        NativeDLLSHA256 = $expectedNativeHash
        NativeVersion = '0.3.5 Release, ABI 8'
        Origin = 'Retained artifacts/atlas-viewport-0.3.5; each copied file checked against the pinned issued manifest.'
        Scope = 'Native DLL, app-local runtime, fonts, legal notices and original core/renderer provenance only. No WPF host.'
        Rebuilt = $false
        Files = @($issuedFiles | ForEach-Object { [ordered]@{ Path = $_; SHA256 = $issuedHashes[$_] } })
    }
    PackagingGitHead = $packageHead
    PackagingGitDirty = ($packageStatus.Count -gt 0)
    PackagingGitStatus = $packageStatus
    PackagingSourceFiles = $packagingSourceHashes
    Validation = 'Packaging verifies file identities only. Local runtime and Windows 7 results must be recorded separately.'
    ProvenanceScope = 'Diagnostic source and canonical ABI header are build-input snapshots. They do not claim to reconstruct the original native DLL bytes.'
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 10), $utf8)
$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $relativePath = $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    "$hash  $relativePath"
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)
Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
Write-Host "VT7 resource lifetime package: $packageRoot"
Write-Host "VT7 resource lifetime archive: $zipPath"
Write-Host "Archive SHA256: $archiveHash"
[pscustomobject]@{ PackageDirectory = $packageRoot; ArchivePath = $zipPath; ArchiveSHA256 = $archiveHash; BuildDirectory = $buildRoot }
