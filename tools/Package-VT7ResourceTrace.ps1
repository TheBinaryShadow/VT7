[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactRoot = Join-Path $repositoryRoot 'artifacts'
$issuedRoot = Join-Path $artifactRoot 'resource-lifetime-0.2'
$issuedArchivePath = Join-Path $artifactRoot 'VT7-resource-lifetime-0.2-x64.zip'
$issuedManifestPath = Join-Path $issuedRoot 'SHA256SUMS.txt'
$traceSourceRoot = Join-Path $repositoryRoot 'src\vt7\VT7.ResourceTrace'
$packageRoot = Join-Path $artifactRoot 'resource-trace-0.3'
$archivePath = Join-Path $artifactRoot 'VT7-resource-trace-0.3-x64.zip'
$nativePdbPath = Join-Path $artifactRoot 'atlas-viewport-0.3.5\symbols\VT7.Native.pdb'

$expectedIssuedArchiveHash = '8F2F1014A96B1781486574E4FF92AD8B43823CB96EC90BA1A2E71B656C03F388'
$expectedIssuedManifestHash = '1C31C6CFD53913A629AC8AB9B14EA259C3E52125871D509AF047F852804FB41D'
$expectedExecutableHash = '438FC74130CE3D7A255BEDF368FEA1371778CB0A85CF9D5EBCF1A295C246F71F'
$expectedExecutablePdbHash = 'C2696000C6829C54DE5CA284379ED199E06E773A2ECE5308B29257A32B76F02B'
$expectedNativeHash = '0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49'
$expectedNativePdbHash = 'C835ED74D7E119F0601AD1CE1DE8A70349BADD443D041E467756705CC8B6AAEE'

foreach ($outputPath in @($packageRoot, $archivePath)) {
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to replace an existing trace candidate: $outputPath. Preserve it and assign a new package identity before packaging again."
    }
}
function Assert-TraceFileHash {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required trace package input is missing: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) { throw "SHA256 mismatch for $Path. Expected $Expected; found $actual." }
}
function Copy-TraceVerifiedFile {
    param([string]$SourcePath, [string]$RelativeDestination, [string]$ExpectedHash)
    $destinationPath = Join-Path $packageRoot $RelativeDestination
    if (Test-Path -LiteralPath $destinationPath) { throw "Refusing to replace a file while assembling the trace package: $RelativeDestination" }
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination $destinationPath
    Assert-TraceFileHash $destinationPath $ExpectedHash
}

# The archive identity and its extracted checksum manifest are pinned independently.
# Validate every inherited file, including all original legal/provenance material.
Assert-TraceFileHash $issuedArchivePath $expectedIssuedArchiveHash
Assert-TraceFileHash $issuedManifestPath $expectedIssuedManifestHash
Assert-TraceFileHash (Join-Path $issuedRoot 'VT7.ResourceLifetime.exe') $expectedExecutableHash
Assert-TraceFileHash (Join-Path $issuedRoot 'symbols\VT7.ResourceLifetime.pdb') $expectedExecutablePdbHash
Assert-TraceFileHash (Join-Path $issuedRoot 'VT7.Native.dll') $expectedNativeHash
Assert-TraceFileHash $nativePdbPath $expectedNativePdbHash
$issuedHashes = @{}
foreach ($line in [IO.File]::ReadAllLines($issuedManifestPath)) {
    if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Malformed issued checksum entry: $line" }
    $relativePath = $Matches[2]
    $expectedHash = $Matches[1].ToUpperInvariant()
    if ([IO.Path]::IsPathRooted($relativePath) -or $relativePath.Contains(':') -or
        $relativePath -match '(^|[\\/])\.\.?([\\/]|$)' -or $issuedHashes.ContainsKey($relativePath)) {
        throw "Invalid or duplicate issued checksum path: $relativePath"
    }
    $issuedHashes[$relativePath] = $expectedHash
    Assert-TraceFileHash (Join-Path $issuedRoot $relativePath) $expectedHash
}
$issuedHashes['SHA256SUMS.txt'] = $expectedIssuedManifestHash

if (-not (Test-Path -LiteralPath $traceSourceRoot -PathType Container)) { throw "Trace source directory is missing: $traceSourceRoot" }
$traceFiles = @(Get-ChildItem -LiteralPath $traceSourceRoot -File -Recurse | Sort-Object FullName)
foreach ($requiredName in @('Run-ResourceTrace.ps1', 'RUN-RESOURCE-TRACE.cmd', 'README.txt', 'preflight.cdb', 'startup.cdb', 'trace.cdb', 'Validate-ResourceTrace.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $traceSourceRoot $requiredName) -PathType Leaf)) {
        throw "Required trace source is missing: $requiredName"
    }
}
$traceInputs = @()
foreach ($file in $traceFiles) {
    if (@('.ps1', '.cmd', '.txt', '.md', '.json', '.cdb') -notcontains $file.Extension.ToLowerInvariant()) {
        throw "Unexpected non-text trace source input: $($file.FullName). Debuggers and other new binaries must not be redistributed by this helper."
    }
    $packagePath = $file.FullName.Substring($traceSourceRoot.Length + 1).Replace('\', '/')
    if ($packagePath -eq 'PACKAGE-MANIFEST.json' -or $packagePath -eq 'SHA256SUMS.txt' -or
        $packagePath.StartsWith('provenance/', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Trace source conflicts with package provenance: $packagePath"
    }
    $traceInputs += [ordered]@{
        SourcePath = $file.FullName
        RepositoryPath = $file.FullName.Substring($repositoryRoot.Length + 1).Replace('\', '/')
        PackagePath = $packagePath
        SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
}
$packagerRepositoryPath = 'tools/Package-VT7ResourceTrace.ps1'
$packagerPath = Join-Path $repositoryRoot $packagerRepositoryPath
$packagerHash = (Get-FileHash -LiteralPath $packagerPath -Algorithm SHA256).Hash
$testSources = @()
foreach ($relativePath in @('tools/Test-VT7ResourceTrace.ps1', 'tools/Test-VT7TraceExceptionPolicy.ps1',
        'tools/Test-VT7TraceFallback.ps1', 'tools/testdata/VT7TraceExceptionFixture.cpp')) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing trace regression source: $relativePath" }
    $testSources += [ordered]@{ RepositoryPath = $relativePath; SHA256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
}
$sourceHead = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not read the trace packaging Git HEAD.' }
$sourceStatus = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Could not read the trace packaging Git status.' }

$rootRuntimeFiles = @(
    'VT7.ResourceLifetime.exe', 'VT7.Native.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll',
    'LICENSE.txt', 'NOTICE.md', 'CORE-PROVENANCE.md', 'RENDERER-PROVENANCE.md'
)
$inheritedFiles = @()
foreach ($relativePath in @($issuedHashes.Keys | Sort-Object)) {
    $runtimeLocation = $rootRuntimeFiles -contains $relativePath
    foreach ($directory in @('fonts/', 'licenses/', 'symbols/')) {
        if ($relativePath.StartsWith($directory, [StringComparison]::OrdinalIgnoreCase)) { $runtimeLocation = $true }
    }
    $destinationPath = if ($runtimeLocation) { $relativePath } else { 'provenance/issued-resource-lifetime-0.2/' + $relativePath }
    $inheritedFiles += [ordered]@{ OriginalPath = $relativePath; PackagePath = $destinationPath; SHA256 = $issuedHashes[$relativePath] }
}

New-Item -ItemType Directory -Path $packageRoot | Out-Null
foreach ($file in $inheritedFiles) {
    Copy-TraceVerifiedFile (Join-Path $issuedRoot $file.OriginalPath) $file.PackagePath $file.SHA256
}
Copy-TraceVerifiedFile $nativePdbPath 'symbols/VT7.Native.pdb' $expectedNativePdbHash
$traceSourceFiles = @()
foreach ($file in $traceInputs) {
    # Copy once to a provenance snapshot, then use those exact bytes at runtime.
    $snapshotPath = 'provenance/trace-source/' + $file.RepositoryPath
    Copy-TraceVerifiedFile $file.SourcePath $snapshotPath $file.SHA256
    Copy-TraceVerifiedFile (Join-Path $packageRoot $snapshotPath) $file.PackagePath $file.SHA256
    $traceSourceFiles += [ordered]@{ RepositoryPath = $file.RepositoryPath; PackagePath = $file.PackagePath; SnapshotPath = $snapshotPath; SHA256 = $file.SHA256 }
}
Copy-TraceVerifiedFile $packagerPath ('provenance/trace-source/' + $packagerRepositoryPath) $packagerHash
foreach ($file in $testSources) {
    Copy-TraceVerifiedFile (Join-Path $repositoryRoot $file.RepositoryPath) ('provenance/trace-source/' + $file.RepositoryPath) $file.SHA256
}
$manifest = [ordered]@{
    Package = 'VT7 resource trace'
    PackageVersion = '0.3'
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    Purpose = 'Process-scoped attribution of the retained Windows 7 WARP resource growth. A completed trace is not resource-growth acceptance.'
    SourceGitHead = $sourceHead
    SourceGitDirty = ($sourceStatus.Count -gt 0)
    SourceGitStatus = $sourceStatus
    IssuedMeasurement = [ordered]@{
        Package = 'VT7-resource-lifetime-0.2-x64.zip'
        ArchiveSHA256 = $expectedIssuedArchiveHash
        OriginalManifestSHA256 = $expectedIssuedManifestHash
        ArchivedManifest = 'provenance/issued-resource-lifetime-0.2/SHA256SUMS.txt'
        ArchivedPackageManifest = 'provenance/issued-resource-lifetime-0.2/PACKAGE-MANIFEST.json'
        Executable = 'VT7.ResourceLifetime.exe'
        ExecutableSHA256 = $expectedExecutableHash
        ExecutablePDB = 'symbols/VT7.ResourceLifetime.pdb'
        ExecutablePDBSHA256 = $expectedExecutablePdbHash
        ExecutablePDBGuid = '1BD53D05-F89C-48A7-83DE-B8E27825D374'
        ExecutablePDBAge = 1
        NativeDLL = 'VT7.Native.dll'
        NativeDLLSHA256 = $expectedNativeHash
        Rebuilt = $false
        Files = $inheritedFiles
        Mapping = 'Executable/runtime/fonts/licenses/symbols and core/renderer notices retain their runtime paths. Other original files retain exact bytes under provenance/issued-resource-lifetime-0.2/, with this explicit original-to-package path map.'
    }
    AddedNativeSymbols = [ordered]@{
        Source = 'artifacts/atlas-viewport-0.3.5/symbols/VT7.Native.pdb'
        PackagePath = 'symbols/VT7.Native.pdb'
        SHA256 = $expectedNativePdbHash
        PDBGuid = 'ED268A2C-CE8E-4B5B-8549-1DD819575BAD'
        PDBAge = 15
        MatchEvidence = 'These exact DLL/PDB and EXE/PDB hash pairs were independently verified with local symchk. Packaging rechecks pinned file identities; runtime symbol loading remains a trace readiness check.'
    }
    TraceSourceFiles = $traceSourceFiles
    PackagingScript = [ordered]@{ RepositoryPath = $packagerRepositoryPath; SHA256 = $packagerHash }
    RegressionTestSources = $testSources
    Debugger = 'Not redistributed. A compatible independently installed debugger is required by the trace instructions.'
    Validation = 'This helper verifies package identities only and runs no debugger or measurement. Trace readiness and target findings must be recorded separately.'
    ProvenanceScope = 'Retained 0.2 measurement and issued 0.3.5 native bytes are unchanged. Trace 0.3 adds a separate startup control and activates NT handle tracing at pre-warmup, before surface creation. Trace 0.1 and 0.2 remain preserved.'
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 10), $utf8)
$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $relativePath = $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    "$hash  $relativePath"
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)
Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
Write-Host "VT7 resource trace package: $packageRoot"
Write-Host "VT7 resource trace archive: $archivePath"
Write-Host "Archive SHA256: $archiveHash"
[pscustomobject]@{ PackageDirectory = $packageRoot; ArchivePath = $archivePath; ArchiveSHA256 = $archiveHash }
