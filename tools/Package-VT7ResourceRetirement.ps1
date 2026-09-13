[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BuildDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactRoot = Join-Path $repositoryRoot 'artifacts'
$issuedRoot = Join-Path $artifactRoot 'resource-lifetime-0.2'
$issuedArchivePath = Join-Path $artifactRoot 'VT7-resource-lifetime-0.2-x64.zip'
$issuedManifestPath = Join-Path $issuedRoot 'SHA256SUMS.txt'
$collectorSourceRoot = Join-Path $repositoryRoot 'src\vt7\VT7.ResourceRetirement'
$packageRoot = Join-Path $artifactRoot 'resource-retirement-0.1'
$archivePath = Join-Path $artifactRoot 'VT7-resource-retirement-0.1-x64.zip'
$nativePdbPath = Join-Path $artifactRoot 'atlas-viewport-0.3.5\symbols\VT7.Native.pdb'
$buildRoot = [IO.Path]::GetFullPath($BuildDirectory)

$expectedIssuedArchiveHash = '8F2F1014A96B1781486574E4FF92AD8B43823CB96EC90BA1A2E71B656C03F388'
$expectedIssuedManifestHash = '1C31C6CFD53913A629AC8AB9B14EA259C3E52125871D509AF047F852804FB41D'
$expectedOldExecutableHash = '438FC74130CE3D7A255BEDF368FEA1371778CB0A85CF9D5EBCF1A295C246F71F'
$expectedOldExecutablePdbHash = 'C2696000C6829C54DE5CA284379ED199E06E773A2ECE5308B29257A32B76F02B'
$expectedNativeHash = '0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49'
$expectedNativePdbHash = 'C835ED74D7E119F0601AD1CE1DE8A70349BADD443D041E467756705CC8B6AAEE'

# Every issued or partial candidate is evidence. Do not remove or replace it.
foreach ($outputPath in @($packageRoot, $archivePath)) {
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to replace an existing retirement candidate: $outputPath. Preserve it and assign a new package identity before packaging again."
    }
}
function Assert-RetirementRelativePath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path) -or [IO.Path]::IsPathRooted($Path) -or $Path.Contains(':') -or
        $Path.Contains('\') -or $Path -match '(^|/)\.\.?(/|$)' -or $Path.Contains('//') -or $Path.EndsWith('/')) {
        throw "Invalid package-relative path: $Path"
    }
}
function Assert-RetirementFileHash {
    param([string]$Path, [string]$Expected)
    if ($Expected -notmatch '^[0-9a-fA-F]{64}$') { throw "Invalid expected SHA256 for $Path" }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required retirement package input is missing: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) { throw "SHA256 mismatch for $Path. Expected $Expected; found $actual." }
}
function Copy-RetirementVerifiedFile {
    param([string]$SourcePath, [string]$RelativeDestination, [string]$ExpectedHash)
    Assert-RetirementRelativePath $RelativeDestination
    $destinationPath = Join-Path $packageRoot $RelativeDestination
    if (Test-Path -LiteralPath $destinationPath) { throw "Refusing to replace a file while assembling the retirement package: $RelativeDestination" }
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination $destinationPath
    Assert-RetirementFileHash $destinationPath $ExpectedHash
}

# Pin both the issued archive and its extracted inventory; verify all inherited
# files including historical sources, fonts, notices and runtime license material.
Assert-RetirementFileHash $issuedArchivePath $expectedIssuedArchiveHash
Assert-RetirementFileHash $issuedManifestPath $expectedIssuedManifestHash
Assert-RetirementFileHash (Join-Path $issuedRoot 'VT7.ResourceLifetime.exe') $expectedOldExecutableHash
Assert-RetirementFileHash (Join-Path $issuedRoot 'symbols\VT7.ResourceLifetime.pdb') $expectedOldExecutablePdbHash
Assert-RetirementFileHash (Join-Path $issuedRoot 'VT7.Native.dll') $expectedNativeHash
Assert-RetirementFileHash $nativePdbPath $expectedNativePdbHash
$issuedHashes = @{}
foreach ($line in [IO.File]::ReadAllLines($issuedManifestPath)) {
    if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Malformed issued checksum entry: $line" }
    $relativePath = $Matches[2]
    $expectedHash = $Matches[1].ToUpperInvariant()
    Assert-RetirementRelativePath $relativePath
    if ($issuedHashes.ContainsKey($relativePath)) { throw "Duplicate issued checksum path: $relativePath" }
    $issuedHashes[$relativePath] = $expectedHash
    Assert-RetirementFileHash (Join-Path $issuedRoot $relativePath) $expectedHash
}
$issuedHashes['SHA256SUMS.txt'] = $expectedIssuedManifestHash

$buildManifestPath = Join-Path $buildRoot 'BUILD-MANIFEST.json'
if (-not (Test-Path -LiteralPath $buildManifestPath -PathType Leaf)) { throw "Completed diagnostic build manifest is missing: $buildManifestPath" }
$buildManifestHash = (Get-FileHash -LiteralPath $buildManifestPath -Algorithm SHA256).Hash
$buildManifest = [IO.File]::ReadAllText($buildManifestPath) | ConvertFrom-Json
Assert-RetirementFileHash $buildManifestPath $buildManifestHash
if ($buildManifest.Diagnostic -ne 'VT7.ResourceRetirement' -or $buildManifest.DiagnosticVersion -ne '0.1' -or
    $buildManifest.BuildStatus -ne 'Completed' -or $buildManifest.Configuration -ne 'Release' -or
    $buildManifest.Architecture -ne 'x64' -or $buildManifest.MSVCToolset -ne '14.44.35207' -or
    $buildManifest.WindowsSDK -ne '10.0.26100.0' -or $buildManifest.Runtime -ne 'Static release CRT (/MT)') {
    throw 'The selected build does not identify a completed, pinned Release x64 resource retirement 0.1 diagnostic.'
}
Assert-RetirementFileHash (Join-Path $buildRoot 'VT7.ResourceRetirement.exe') $buildManifest.ExecutableSHA256
Assert-RetirementFileHash (Join-Path $buildRoot 'VT7.ResourceRetirement.pdb') $buildManifest.SymbolSHA256
$expectedBuildSources = @(
    'src/vt7/VT7.ResourceRetirement/main.cpp',
    'src/vt7/VT7.Native/include/vt7_native.h',
    'tools/Build-VT7ResourceRetirement.ps1'
)
if (@($buildManifest.SourceFiles).Count -ne $expectedBuildSources.Count) { throw 'Unexpected diagnostic build source inventory.' }
foreach ($relativePath in $expectedBuildSources) {
    $sourceEntry = @($buildManifest.SourceFiles | Where-Object { $_.Path -eq $relativePath })
    if ($sourceEntry.Count -ne 1) { throw "Missing or duplicate diagnostic source identity: $relativePath" }
    Assert-RetirementFileHash (Join-Path (Join-Path $buildRoot 'source') $relativePath) $sourceEntry[0].SHA256
    Assert-RetirementFileHash (Join-Path $repositoryRoot $relativePath) $sourceEntry[0].SHA256
}
$buildFiles = @()
foreach ($fileName in @('BUILD-MANIFEST.json', 'BUILD-INPUTS.json', 'build.log', 'compiler.rsp')) {
    $path = Join-Path $buildRoot $fileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing diagnostic build provenance: $path" }
    $buildFiles += [ordered]@{ Path = $fileName; SHA256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
}
if (@($buildFiles | Where-Object { $_.Path -eq 'BUILD-MANIFEST.json' })[0].SHA256 -ne $buildManifestHash) {
    throw 'Diagnostic build manifest changed while preparing packaging inputs.'
}

foreach ($requiredName in @('Run-ResourceRetirement.ps1', 'RUN-RESOURCE-RETIREMENT.cmd', 'README.txt',
        'preflight.cdb', 'startup.cdb', 'retirement.cdb', 'warp-load.cdb', 'warp-verify.cdb', 'warp-hooks.cdb',
        'Validate-ResourceRetirement.ps1', 'main.cpp')) {
    if (-not (Test-Path -LiteralPath (Join-Path $collectorSourceRoot $requiredName) -PathType Leaf)) {
        throw "Required retirement source is missing: $requiredName"
    }
}
$collectorInputs = @()
foreach ($file in @(Get-ChildItem -LiteralPath $collectorSourceRoot -File -Recurse | Sort-Object FullName)) {
    if (@('.ps1', '.cmd', '.txt', '.md', '.json', '.cdb', '.cpp', '.h') -notcontains $file.Extension.ToLowerInvariant()) {
        throw "Unexpected retirement source input: $($file.FullName). Debuggers and Microsoft binaries/PDBs must not be redistributed."
    }
    $packagePath = $file.FullName.Substring($collectorSourceRoot.Length + 1).Replace('\', '/')
    Assert-RetirementRelativePath $packagePath
    if ($packagePath -eq 'PACKAGE-MANIFEST.json' -or $packagePath -eq 'SHA256SUMS.txt' -or
        $packagePath.StartsWith('provenance/', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Retirement source conflicts with package provenance: $packagePath"
    }
    $collectorInputs += [ordered]@{
        SourcePath = $file.FullName
        RepositoryPath = $file.FullName.Substring($repositoryRoot.Length + 1).Replace('\', '/')
        PackagePath = $packagePath
        Runtime = (@('.cpp', '.h') -notcontains $file.Extension.ToLowerInvariant())
        SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
}
foreach ($file in $collectorInputs) {
    $buildSourceEntry = @($buildManifest.SourceFiles | Where-Object { $_.Path -eq $file.RepositoryPath })
    if ($buildSourceEntry.Count -eq 1 -and $file.SHA256 -ne $buildSourceEntry[0].SHA256) {
        throw "Diagnostic source changed after build verification: $($file.RepositoryPath)"
    }
}
$packagerRepositoryPath = 'tools/Package-VT7ResourceRetirement.ps1'
$packagerPath = Join-Path $repositoryRoot $packagerRepositoryPath
$packagerHash = (Get-FileHash -LiteralPath $packagerPath -Algorithm SHA256).Hash
$testSources = @()
foreach ($relativePath in @('tools/Test-VT7ResourceRetirement.ps1', 'tools/Test-VT7ResourceRetirementSampler.ps1',
        'tools/Test-VT7RetirementDebuggerHooks.ps1', 'tools/testdata/VT7RetirementHookFixture.cpp',
        'tools/Test-VT7RetirementExceptionPolicy.ps1', 'tools/Test-VT7RetirementFallback.ps1',
        'tools/Test-VT7TraceExceptionPolicy.ps1', 'tools/Test-VT7TraceFallback.ps1',
        'tools/testdata/VT7TraceExceptionFixture.cpp')) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing retirement regression source: $relativePath" }
    $testSources += [ordered]@{ RepositoryPath = $relativePath; SHA256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
}
$sourceHead = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not read the retirement packaging Git HEAD.' }
$sourceStatus = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Could not read the retirement packaging Git status.' }

$rootRuntimeFiles = @(
    'VT7.Native.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll',
    'LICENSE.txt', 'NOTICE.md', 'CORE-PROVENANCE.md', 'RENDERER-PROVENANCE.md'
)
$inheritedFiles = @()
foreach ($relativePath in @($issuedHashes.Keys | Sort-Object)) {
    $runtimeLocation = $rootRuntimeFiles -contains $relativePath
    foreach ($directory in @('fonts/', 'licenses/')) {
        if ($relativePath.StartsWith($directory, [StringComparison]::OrdinalIgnoreCase)) { $runtimeLocation = $true }
    }
    $destinationPath = if ($runtimeLocation) { $relativePath } else { 'provenance/issued-resource-lifetime-0.2/' + $relativePath }
    $inheritedFiles += [ordered]@{ OriginalPath = $relativePath; PackagePath = $destinationPath; SHA256 = $issuedHashes[$relativePath] }
}

New-Item -ItemType Directory -Path $packageRoot | Out-Null
foreach ($file in $inheritedFiles) {
    Copy-RetirementVerifiedFile (Join-Path $issuedRoot $file.OriginalPath) $file.PackagePath $file.SHA256
}
Copy-RetirementVerifiedFile $nativePdbPath 'symbols/VT7.Native.pdb' $expectedNativePdbHash
Copy-RetirementVerifiedFile (Join-Path $buildRoot 'VT7.ResourceRetirement.exe') 'VT7.ResourceRetirement.exe' $buildManifest.ExecutableSHA256
Copy-RetirementVerifiedFile (Join-Path $buildRoot 'VT7.ResourceRetirement.pdb') 'symbols/VT7.ResourceRetirement.pdb' $buildManifest.SymbolSHA256
foreach ($file in $buildFiles) {
    Copy-RetirementVerifiedFile (Join-Path $buildRoot $file.Path) ('provenance/retirement-build/' + $file.Path) $file.SHA256
}
foreach ($file in $buildManifest.SourceFiles) {
    Copy-RetirementVerifiedFile (Join-Path (Join-Path $buildRoot 'source') $file.Path) ('provenance/retirement-build/source/' + $file.Path) $file.SHA256
}
$collectorSourceFiles = @()
foreach ($file in $collectorInputs) {
    $snapshotPath = 'provenance/retirement-source/' + $file.RepositoryPath
    Copy-RetirementVerifiedFile $file.SourcePath $snapshotPath $file.SHA256
    if ($file.Runtime) {
        # Use the frozen source snapshot, not a second read of the working source.
        Copy-RetirementVerifiedFile (Join-Path $packageRoot $snapshotPath) $file.PackagePath $file.SHA256
    }
    $collectorSourceFiles += [ordered]@{
        RepositoryPath = $file.RepositoryPath
        PackagePath = $(if ($file.Runtime) { $file.PackagePath } else { $null })
        SnapshotPath = $snapshotPath
        SHA256 = $file.SHA256
    }
}
Copy-RetirementVerifiedFile $packagerPath ('provenance/retirement-source/' + $packagerRepositoryPath) $packagerHash
foreach ($file in $testSources) {
    Copy-RetirementVerifiedFile (Join-Path $repositoryRoot $file.RepositoryPath) ('provenance/retirement-source/' + $file.RepositoryPath) $file.SHA256
}
$manifest = [ordered]@{
    Package = 'VT7 resource retirement'
    PackageVersion = '0.1'
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    Purpose = 'Observe WARP work cleanup and later Windows pool-worker retirement. Collection completion is not resource-growth acceptance.'
    SourceGitHead = $sourceHead
    SourceGitDirty = ($sourceStatus.Count -gt 0)
    SourceGitStatus = $sourceStatus
    Diagnostic = [ordered]@{
        Executable = 'VT7.ResourceRetirement.exe'
        ExecutableSHA256 = $buildManifest.ExecutableSHA256
        ExecutablePDB = 'symbols/VT7.ResourceRetirement.pdb'
        ExecutablePDBSHA256 = $buildManifest.SymbolSHA256
        SampleExport = 'VT7RetirementSample'
        BuildManifest = 'provenance/retirement-build/BUILD-MANIFEST.json'
        BuildManifestSHA256 = $buildManifestHash
        BuildProvenance = $buildFiles
        SourceGitHead = $buildManifest.SourceGitHead
        SourceGitDirty = $buildManifest.SourceGitDirty
        Runtime = $buildManifest.Runtime
        MSVCToolset = $buildManifest.MSVCToolset
        WindowsSDK = $buildManifest.WindowsSDK
        Rebuilt = $true
    }
    Workload = [ordered]@{
        Backend = 'Forced WARP'
        Lifetime = 'One reused surface; one create/destroy pair'
        WarmupIterations = 2
        MeasuredIterations = 25
        Checkpoints = 8
        PostCloseSeconds = @(10, 90, 180)
        FullCollectionTimeoutSeconds = 600
        Acceptance = 'Existing integrated budgets are unchanged; this is an ownership/retirement diagnostic, not an integrated timed soak.'
    }
    IssuedMeasurement = [ordered]@{
        Package = 'VT7-resource-lifetime-0.2-x64.zip'
        ArchiveSHA256 = $expectedIssuedArchiveHash
        OriginalManifestSHA256 = $expectedIssuedManifestHash
        ArchivedManifest = 'provenance/issued-resource-lifetime-0.2/SHA256SUMS.txt'
        ArchivedPackageManifest = 'provenance/issued-resource-lifetime-0.2/PACKAGE-MANIFEST.json'
        ArchivedExecutable = 'provenance/issued-resource-lifetime-0.2/VT7.ResourceLifetime.exe'
        ArchivedExecutableSHA256 = $expectedOldExecutableHash
        ArchivedExecutablePDB = 'provenance/issued-resource-lifetime-0.2/symbols/VT7.ResourceLifetime.pdb'
        ArchivedExecutablePDBSHA256 = $expectedOldExecutablePdbHash
        NativeDLL = 'VT7.Native.dll'
        NativeDLLSHA256 = $expectedNativeHash
        NativeVersion = '0.3.5 Release, ABI 8'
        NativeRebuilt = $false
        Files = $inheritedFiles
        Mapping = 'Native/runtime/fonts/licenses and core/renderer notices retain their runtime paths. All other original files, including the lifetime 0.2 EXE/PDB, retain exact bytes under provenance/issued-resource-lifetime-0.2/ with this explicit path map.'
    }
    AddedNativeSymbols = [ordered]@{
        Source = 'artifacts/atlas-viewport-0.3.5/symbols/VT7.Native.pdb'
        PackagePath = 'symbols/VT7.Native.pdb'
        SHA256 = $expectedNativePdbHash
        PDBGuid = 'ED268A2C-CE8E-4B5B-8549-1DD819575BAD'
        PDBAge = 15
        MatchEvidence = 'The unchanged issued native DLL/PDB pair was independently verified with local symchk. Packaging rechecks pinned identities; runtime symbol loading remains a readiness check.'
    }
    RetirementSourceFiles = $collectorSourceFiles
    PackagingScript = [ordered]@{ RepositoryPath = $packagerRepositoryPath; SHA256 = $packagerHash }
    RegressionTestSources = $testSources
    PrivateWARPProfile = 'Private offsets require the guarded Windows 7 D3D10Warp 6.2.9200.22592 x64 profile. Unsupported profiles do not qualify Windows 7 ownership hooks; local Windows 10 runs qualify collection only.'
    Debugger = 'Not redistributed. Uses the independently installed compatible x64 debugger. No Microsoft WARP DLL/PDB or downloaded Microsoft symbol data is redistributed.'
    Validation = 'Packaging verifies file identities and ZIP contents only. Local collector qualification and target findings must be recorded separately.'
    ProvenanceScope = 'The standalone retirement EXE is new. Issued native 0.3.5 and inherited lifetime 0.2 payload bytes are unchanged. Prior candidates and their original manifests remain preserved.'
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 12), $utf8)
$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $relativePath = $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    "$hash  $relativePath"
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)
Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $archivePath -CompressionLevel Optimal

# Compare every ZIP file directly with the assembled candidate, including its
# checksum manifest, without extracting or executing any packaged file.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$expectedArchiveFiles = @{}
foreach ($file in @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse)) {
    $relativePath = $file.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    $expectedArchiveFiles[$relativePath] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $relativePath = $entry.FullName.Replace('\', '/')
        Assert-RetirementRelativePath $relativePath
        if ($seen.ContainsKey($relativePath) -or -not $expectedArchiveFiles.ContainsKey($relativePath)) {
            throw "Unexpected or duplicate ZIP file: $relativePath. Partial candidate is retained."
        }
        $stream = $entry.Open()
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try { $actualHash = [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '') }
        finally { $sha256.Dispose(); $stream.Dispose() }
        if ($actualHash -ne $expectedArchiveFiles[$relativePath]) { throw "ZIP content hash mismatch: $relativePath" }
        $seen[$relativePath] = $true
    }
    if ($seen.Count -ne $expectedArchiveFiles.Count) { throw 'ZIP is missing one or more packaged files. Partial candidate is retained.' }
}
finally { $archive.Dispose() }
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
$manifestHash = (Get-FileHash -LiteralPath (Join-Path $packageRoot 'SHA256SUMS.txt') -Algorithm SHA256).Hash
Write-Host "VT7 resource retirement package: $packageRoot"
Write-Host "VT7 resource retirement archive: $archivePath"
Write-Host "Archive SHA256: $archiveHash"
Write-Host "Verified ZIP files: $($seen.Count)"
[pscustomobject]@{
    PackageDirectory = $packageRoot
    ArchivePath = $archivePath
    ArchiveSHA256 = $archiveHash
    ManifestSHA256 = $manifestHash
    BuildDirectory = $buildRoot
    VerifiedArchiveFiles = $seen.Count
}
