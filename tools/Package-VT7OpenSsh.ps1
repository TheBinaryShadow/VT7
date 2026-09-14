[CmdletBinding()]
param(
    [string]$PackageName = 'VT7-OpenSSH-S00-Preflight-0.2-x64'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')

if ($PackageName -notmatch '^VT7-OpenSSH-S00-Preflight-[0-9.]+-x64$') {
    throw "Invalid S00 package name: $PackageName"
}
foreach ($path in @($packageRoot, $archivePath)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to replace an existing S00 package: $path" }
}

$inputs = [ordered]@{
    'Test-VT7OpenSsh.ps1' = Join-Path $PSScriptRoot 'Test-VT7OpenSsh.ps1'
    'Run-OpenSshS00Preflight.ps1' = Join-Path $repositoryRoot 'src\vt7\VT7.OpenSshProbe\Run-OpenSshS00Preflight.ps1'
    'RUN-OPENSSH-S00-PREFLIGHT.cmd' = Join-Path $repositoryRoot 'src\vt7\VT7.OpenSshProbe\RUN-OPENSSH-S00-PREFLIGHT.cmd'
    'README.txt' = Join-Path $repositoryRoot 'src\vt7\VT7.OpenSshProbe\README.txt'
    'LICENSE.txt' = Join-Path $repositoryRoot 'LICENSE'
    'NOTICE.md' = Join-Path $repositoryRoot 'NOTICE.md'
}
foreach ($source in $inputs.Values) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "S00 package input is missing: $source" }
}

New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
foreach ($name in $inputs.Keys) {
    Copy-Item -LiteralPath $inputs[$name] -Destination (Join-Path $packageRoot $name)
}

$head = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all)
$manifest = [ordered]@{
    schema = 'vt7-openssh-s00-preflight-package-v1'
    package = $PackageName
    createdUtc = [DateTime]::UtcNow.ToString('o')
    architecture = 'x64'
    sourceGitHead = $head
    sourceGitDirty = ($status.Count -gt 0)
    bundledOpenSsh = $false
    expectedClientLocation = 'C:\Program Files\OpenSSH\ssh.exe or ssh.exe on PATH'
    scope = 'Endpoint-independent S00 OpenSSH identity, raw-channel, isolated-configuration, algorithm and cancellation preflight'
    remaining = 'Network trust, authentication, remote byte, PTY size, live window-change and final-drain cases'
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $packageRoot 'PACKAGE-MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)

$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -File | Sort-Object Name | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.Name
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)

$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -File) {
    $expected[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
$seen = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name) -or $entry.FullName -ne $entry.Name) {
            throw "Unexpected S00 ZIP entry: $($entry.FullName)"
        }
        if ($seen.ContainsKey($entry.Name) -or -not $expected.ContainsKey($entry.Name)) {
            throw "Duplicate or unknown S00 ZIP entry: $($entry.Name)"
        }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$entry.Name]) { throw "S00 ZIP entry hash mismatch: $($entry.Name)" }
        $seen[$entry.Name] = $true
    }
}
finally {
    $archive.Dispose()
}
if ($seen.Count -ne $expected.Count) { throw 'S00 ZIP is missing one or more staged files.' }

[pscustomobject]@{
    PackageDirectory = $packageRoot
    ArchivePath = $archivePath
    ArchiveSHA256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    Bytes = (Get-Item -LiteralPath $archivePath).Length
    Files = $seen.Count
}
