[CmdletBinding()]
param([string]$PackageName = 'VT7-Legacy-Win7-0.2-x64')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$baseline = Join-Path $packageParent 'VT7-Legacy-Win7-0.1-x64.zip'
$baselineSha256 = '5E94F09166C17683083729BD91B442FF0C407697A45E81B8715889A4E7C864F3'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')
$binaryRoot = Join-Path $repositoryRoot 'artifacts\vt7\bin\Release'
if ($PackageName -ne 'VT7-Legacy-Win7-0.2-x64') { throw 'Unexpected legacy candidate name.' }
foreach ($path in @($packageRoot, $archivePath)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to replace existing candidate: $path" }
}
if ((Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash -ne $baselineSha256) {
    throw 'The accepted KH01.4 dependency closure has changed.'
}
$hostPath = Join-Path $binaryRoot 'VT7.Host.exe'
if ([Diagnostics.FileVersionInfo]::GetVersionInfo($hostPath).FileVersion -ne '0.12.5.0') {
    throw 'Build the 0.12.5 Release host before packaging.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($baseline, $packageRoot)
Move-Item -LiteralPath (Join-Path $packageRoot 'README.txt') -Destination (Join-Path $packageRoot 'LEGACY-0.1-README.txt')
Copy-Item -LiteralPath $hostPath -Destination (Join-Path $packageRoot 'VT7.Host.exe')
Copy-Item -LiteralPath (Join-Path $binaryRoot 'VT7.Host.exe.config') -Destination (Join-Path $packageRoot 'VT7.Host.exe.config')
Copy-Item -LiteralPath (Join-Path $binaryRoot 'VT7.Host.pdb') -Destination (Join-Path $packageRoot 'symbols\VT7.Host.pdb')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'src\vt7\packaging\RUN-VT7-LEGACY-BASELINE.cmd') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'src\vt7\packaging\RUN-VT7-WINDOWS-POWERSHELL.cmd') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'src\vt7\packaging\LEGACY-WIN7-0-2-README.txt') -Destination (Join-Path $packageRoot 'README.txt')

& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -BinaryDirectory $packageRoot -AllowAnyCpuManaged

$manifestPath = Join-Path $packageRoot 'PACKAGE-MANIFEST.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.schema = 'vt7-legacy-win7-no-openssh-package-v1'
$manifest.package = $PackageName
$manifest.createdUtc = [DateTime]::UtcNow.ToString('o')
$manifest.applicationVersion = '0.12.5'
$manifest.scope = 'Pre-WMF 5.1 Windows 7 SP1 baseline and bundled interactive SSH shim without installed OpenSSH'
$manifest.baselineArchiveSha256 = $baselineSha256
$manifest.windowsPowerShell2Qualified = $false
$manifest.legacyCmdRunner = 'RUN-VT7-LEGACY-BASELINE.cmd'
$manifest | Add-Member -NotePropertyName embeddedSshWithoutOpenSsh -NotePropertyValue $true
$manifest.sourceGitHead = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$manifest.sourceGitDirty = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all).Count -gt 0
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8)

$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object FullName | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)

$oldNoPause = $env:VT7_TEST_NO_PAUSE
$oldOutput = $env:VT7_TEST_OUTPUT_DIRECTORY
try {
    $env:VT7_TEST_NO_PAUSE = '1'
    $env:VT7_TEST_OUTPUT_DIRECTORY = Join-Path $packageParent ($PackageName + '-local-logs')
    & (Join-Path $env:SystemRoot 'System32\cmd.exe') /d /c ('"' + (Join-Path $packageRoot 'RUN-VT7-LEGACY-BASELINE.cmd') + '"')
    if ($LASTEXITCODE -ne 0) { throw "Packaged legacy launcher failed with exit code $LASTEXITCODE." }
}
finally {
    $env:VT7_TEST_NO_PAUSE = $oldNoPause
    $env:VT7_TEST_OUTPUT_DIRECTORY = $oldOutput
}

[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -Recurse -File) {
    $relative = $file.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
    $expected[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$seen = @{}
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $name = $entry.FullName.Replace('\', '/')
        if ($name.StartsWith('/') -or $name.Split('/') -contains '..') { throw "Unsafe archive entry: $name" }
        if ($seen.ContainsKey($name) -or -not $expected.ContainsKey($name)) { throw "Unexpected archive entry: $name" }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$name]) { throw "Archive entry hash mismatch: $name" }
        $seen[$name] = $true
    }
}
finally { $archive.Dispose() }
if ($seen.Count -ne $expected.Count) { throw 'Archive is missing staged files.' }

[pscustomobject]@{
    PackageDirectory = $packageRoot
    ArchivePath = $archivePath
    ArchiveSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    Bytes = (Get-Item -LiteralPath $archivePath).Length
    Files = $seen.Count
}
