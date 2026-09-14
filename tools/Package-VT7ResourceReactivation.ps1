[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$BuildDirectory, [Parameter(Mandatory=$true)][string]$QualificationDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$build = [IO.Path]::GetFullPath($BuildDirectory)
$qualification = [IO.Path]::GetFullPath($QualificationDirectory)
$issued = Join-Path $root 'artifacts/atlas-viewport-0.3.5'
$package = Join-Path $root 'artifacts/resource-reactivation-0.1'
$zip = Join-Path $root 'artifacts/VT7-resource-reactivation-0.1-x64.zip'
foreach ($path in @($package, $zip)) { if (Test-Path -LiteralPath $path) { throw "Refusing to replace an existing candidate: $path" } }
function Assert-ReactivationPath { param([string]$Path)
    if ([string]::IsNullOrEmpty($Path) -or [IO.Path]::IsPathRooted($Path) -or $Path.Contains(':') -or $Path.Contains('\') -or $Path.Contains('//') -or $Path.EndsWith('/') -or $Path -match '(^|/)\.\.?(/|$)') { throw "Invalid package path: $Path" }
}
function Assert-ReactivationHash { param([string]$Path, [string]$Hash)
    if ($Hash -notmatch '^[0-9A-Fa-f]{64}$' -or (Get-FileHash -LiteralPath $Path).Hash -ne $Hash) { throw "Hash mismatch: $Path" }
}
$inputs = New-Object Collections.ArrayList
function Add-ReactivationFile { param([string]$Source, [string]$Destination, [string]$Hash)
    Assert-ReactivationPath $Destination
    Assert-ReactivationHash $Source $Hash
    if (@($inputs | Where-Object { $_.PackagePath -eq $Destination }).Count -ne 0) { throw "Duplicate package destination: $Destination" }
    [void]$inputs.Add([ordered]@{ SourcePath = $Source; PackagePath = $Destination; SHA256 = $Hash })
}
$nativeHash = '0FB473D41905BFCB34BEB3EF5A42EA162293271864B051E3804A0DD2ACABBB49'
$exeHash = '324D29DE31F3B5A10F802D6C0BEA9603EE07098C61F47996C9398BACEC45F843'
$issuedManifestHash = '633D0C890D8F3EF64531AF8A067F556663B2B3F2C56CD2B1362F8106464FA2EA'
$issuedZipHash = '57B2EE43BB9A1AC6AB227B7C7BE4E3FCB88C765753FDEDD988E14EF375604C86'
Assert-ReactivationHash (Join-Path $root 'artifacts/VT7-atlas-viewport-0.3.5-x64.zip') $issuedZipHash
Assert-ReactivationHash (Join-Path $issued 'SHA256SUMS.txt') $issuedManifestHash
Assert-ReactivationHash (Join-Path $issued 'VT7.Native.dll') $nativeHash
$inherited = @(); $inheritedSeen = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $issued 'SHA256SUMS.txt'))) {
    if ($line -notmatch '^([a-fA-F0-9]{64})  (.+)$') { throw 'Invalid issued manifest entry.' }
    $hash = $Matches[1]; $relative = $Matches[2]; Assert-ReactivationPath $relative
    if ($inheritedSeen.ContainsKey($relative)) { throw 'Duplicate inherited file.' }; $inheritedSeen[$relative] = $true
    $runtime = $relative -match '^(fonts/|licenses/|VT7.Native.dll$|msvcp140.dll$|vcruntime140.dll$|vcruntime140_1.dll$|LICENSE.txt$|NOTICE.md$|CORE-PROVENANCE.md$|RENDERER-PROVENANCE.md$|symbols/VT7.Native.pdb$)'
    $destination = if ($runtime) { $relative } else { 'provenance/issued-atlas-viewport-0.3.5/' + $relative }
    Add-ReactivationFile (Join-Path $issued $relative) $destination $hash
    $inherited += [ordered]@{ OriginalPath = $relative; PackagePath = $destination; SHA256 = $hash }
}
Add-ReactivationFile (Join-Path $issued 'SHA256SUMS.txt') 'provenance/issued-atlas-viewport-0.3.5/SHA256SUMS.txt' $issuedManifestHash
$manifest = Get-Content -LiteralPath (Join-Path $build 'BUILD-MANIFEST.json') -Raw | ConvertFrom-Json
if ($manifest.BuildStatus -ne 'Completed' -or $manifest.Diagnostic -ne 'VT7.ResourceReactivation' -or $manifest.DiagnosticVersion -ne '0.1' -or $manifest.TargetFramework -ne 'net48' -or $manifest.Architecture -ne 'x64') { throw 'Build identity is not the completed x64/net48 diagnostic 0.1.' }
Assert-ReactivationHash (Join-Path $build 'bin/VT7.ResourceReactivation.exe') $exeHash
foreach ($file in $manifest.OutputFiles) {
    Assert-ReactivationPath $file.Path
    $destination = Split-Path -Leaf $file.Path
    if ($destination.EndsWith('.pdb')) { $destination = 'symbols/' + $destination }
    Add-ReactivationFile (Join-Path $build $file.Path) $destination $file.SHA256
}
foreach ($file in $manifest.SourceFiles) {
    Assert-ReactivationPath $file.Path
    if ($file.Path -ne 'global.json') { Assert-ReactivationHash (Join-Path $root $file.Path) $file.SHA256 }
    Add-ReactivationFile (Join-Path (Join-Path $build 'source') $file.Path) ('provenance/reactivation-build/source/' + $file.Path) $file.SHA256
}
foreach ($name in @('BUILD-MANIFEST.json','BUILD-INPUTS.json','build.log','build.binlog')) {
    $path = Join-Path $build $name
    Add-ReactivationFile $path ('provenance/reactivation-build/' + $name) (Get-FileHash -LiteralPath $path).Hash
}
. (Join-Path $root 'src/vt7/VT7.ResourceReactivation/Validate-ResourceReactivation.ps1')
$qa = Get-Content -LiteralPath (Join-Path $qualification 'QUALIFICATION.json') -Raw | ConvertFrom-Json
if ($qa.ExecutableSHA256 -ne $exeHash -or $qa.NativeSHA256 -ne $nativeHash -or !$qa.FullProtocolValidated -or !$qa.NegativesPassed -or !$qa.RegularHostChecksPassed) { throw 'Qualification is incomplete or belongs to a different candidate.' }
Assert-ReactivationHash $qa.FullReport.Path $qa.FullReport.SHA256
[void](Test-VT7ReactivationReport $qa.FullReport.Path $qa.FullReport.ExitCode)
foreach ($file in $qa.Files) {
    Assert-ReactivationPath $file.PackagePath
    Add-ReactivationFile $file.Path ('provenance/qualification/' + $file.PackagePath) $file.SHA256
}
Add-ReactivationFile (Join-Path $qualification 'QUALIFICATION.json') 'provenance/qualification/QUALIFICATION.json' (Get-FileHash -LiteralPath (Join-Path $qualification 'QUALIFICATION.json')).Hash
foreach ($name in @('Run-ResourceReactivation.ps1','Validate-ResourceReactivation.ps1','Wait-ResourceReactivation.ps1','RUN-RESOURCE-REACTIVATION.cmd','README.txt')) {
    $path = Join-Path $root ('src/vt7/VT7.ResourceReactivation/' + $name)
    Add-ReactivationFile $path $name (Get-FileHash -LiteralPath $path).Hash
}
foreach ($relative in @('tools/Package-VT7ResourceReactivation.ps1','tools/Test-VT7ResourceReactivation.ps1','tools/Test-VT7ReactivationValidator.ps1','tools/Test-VT7ReactivationRunner.ps1')) {
    $path = Join-Path $root $relative
    Add-ReactivationFile $path ('provenance/reactivation-source/' + $relative) (Get-FileHash -LiteralPath $path).Hash
}
Assert-ReactivationHash (Join-Path $root 'src/vt7/VT7.ResourceReactivation/Validate-ResourceReactivation.ps1') $qa.ValidatorSHA256
Assert-ReactivationHash (Join-Path $root 'src/vt7/VT7.ResourceReactivation/Run-ResourceReactivation.ps1') $qa.RunnerSHA256
Assert-ReactivationHash (Join-Path $root 'src/vt7/VT7.ResourceReactivation/Wait-ResourceReactivation.ps1') $qa.WaitHelperSHA256
$head = (& git -C $root rev-parse HEAD).Trim(); if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git HEAD.' }
$status = @(& git -C $root status --porcelain=v1 --untracked-files=all); if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git status.' }
New-Item -ItemType Directory -Path $package | Out-Null
foreach ($file in $inputs) {
    $destination = Join-Path $package $file.PackagePath
    if (Test-Path -LiteralPath $destination) { throw 'Refusing to replace package content.' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.SourcePath -Destination $destination
    Assert-ReactivationHash $destination $file.SHA256
}
$metadata = [ordered]@{
    Package = 'VT7 WPF resource reactivation'; PackageVersion = '0.1'; CreatedUtc = [DateTime]::UtcNow.ToString('o')
    SourceGitHead = $head; SourceGitDirty = ($status.Count -gt 0); SourceGitStatus = $status
    Diagnostic = 'VT7.ResourceReactivation.exe'; DiagnosticSHA256 = $exeHash
    BuildManifest = 'provenance/reactivation-build/BUILD-MANIFEST.json'; Build = $manifest
    Native = [ordered]@{ Version = '0.3.5 Release, ABI 8'; Rebuilt = $false; SHA256 = $nativeHash }
    Workload = [ordered]@{ Processes = 1; WarmupLifetimes = 2; Rounds = 2; LifecyclesPerRound = 100; IdleTargetsMs = @(10000,90000,180000); BaselineSample = 2; Checkpoints = 16; ImmediateVerdicts = 8; TimeoutSeconds = 2400; TimedSoak = 'Not run' }
    Qualification = 'provenance/qualification/QUALIFICATION.json'
    Acceptance = 'Collection completion and immediate budgets are separate; Windows 7 execution pending; C3 open; timed soak on hold.'
    IssuedArchiveSHA256 = $issuedZipHash; IssuedManifestSHA256 = $issuedManifestHash
    InheritedFiles = $inherited
    Inheritance = 'Native/runtime/fonts/notices/licenses and native symbols keep their runtime paths; other exact original files remain under provenance/issued-atlas-viewport-0.3.5/.'
    InputFiles = $inputs
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $package 'PACKAGE-MANIFEST.json'), ($metadata | ConvertTo-Json -Depth 14), $utf8)
$hashLines = @(Get-ChildItem -LiteralPath $package -File -Recurse | Sort-Object FullName | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($package.Length + 1).Replace('\','/') })
[IO.File]::WriteAllLines((Join-Path $package 'SHA256SUMS.txt'), $hashLines, $utf8)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($package, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $package -File -Recurse) { $expected[$file.FullName.Substring($package.Length + 1).Replace('\','/')] = (Get-FileHash -LiteralPath $file.FullName).Hash }
$archive = [IO.Compression.ZipFile]::OpenRead($zip); $seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $relative = $entry.FullName.Replace('\','/'); Assert-ReactivationPath $relative
        if ($seen.ContainsKey($relative) -or !$expected.ContainsKey($relative)) { throw 'Unexpected or duplicate ZIP entry.' }
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') } finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$relative]) { throw "ZIP hash mismatch: $relative" }; $seen[$relative] = $true
    }
    if ($seen.Count -ne $expected.Count) { throw 'Missing ZIP entries.' }
} finally { $archive.Dispose() }
$result = [ordered]@{ PackageDirectory = $package; ArchivePath = $zip; ArchiveSHA256 = (Get-FileHash -LiteralPath $zip).Hash; Bytes = (Get-Item -LiteralPath $zip).Length; Files = $seen.Count; ManifestSHA256 = (Get-FileHash -LiteralPath (Join-Path $package 'SHA256SUMS.txt')).Hash }
[IO.File]::WriteAllText((Join-Path $qualification 'PACKAGE-VERIFICATION.json'), ($result | ConvertTo-Json), $utf8)
[pscustomobject]$result
