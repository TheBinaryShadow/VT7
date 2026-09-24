[CmdletBinding()]
param([string]$ArchivePath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $ArchivePath) { $ArchivePath = Join-Path $repositoryRoot 'artifacts\vt7\packages\VT7-Legacy-Win7-0.2-x64.zip' }
$archiveFull = [IO.Path]::GetFullPath($ArchivePath)
if (-not (Test-Path -LiteralPath $archiveFull -PathType Leaf)) { throw "Legacy candidate archive is missing: $archiveFull" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($archiveFull)
$entries = @{}
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $name = $entry.FullName.Replace('\', '/')
        if ($name.StartsWith('/') -or $name.Split('/') -contains '..') { throw "Unsafe ZIP entry: $name" }
        if ($entries.ContainsKey($name)) { throw "Duplicate ZIP entry: $name" }
        $stream = $entry.Open()
        $memory = New-Object IO.MemoryStream
        try { $stream.CopyTo($memory); $entries[$name] = $memory.ToArray() }
        finally { $memory.Dispose(); $stream.Dispose() }
    }
}
finally { $archive.Dispose() }

foreach ($required in @('VT7.Host.exe','VT7.Native.dll','shim/ssh.exe','shim/ssh-system.exe',
    'RUN-VT7-LEGACY-BASELINE.cmd','RUN-VT7-COMMAND-PROMPT.cmd','KH01-4-README.txt','LEGACY-0.1-README.txt',
    'README.txt','PACKAGE-MANIFEST.json','SHA256SUMS.txt','LICENSE.txt','NOTICE.md')) {
    if (-not $entries.ContainsKey($required)) { throw "Legacy candidate is missing $required." }
}
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$manifest = $utf8.GetString($entries['PACKAGE-MANIFEST.json']) | ConvertFrom-Json
if ($manifest.schema -ne 'vt7-legacy-win7-no-openssh-package-v1' -or
    $manifest.package -ne 'VT7-Legacy-Win7-0.2-x64' -or
    $manifest.applicationVersion -ne '0.12.5' -or
    $manifest.nativeAbi -ne 11 -or
    $manifest.baselineArchiveSha256 -ne '5E94F09166C17683083729BD91B442FF0C407697A45E81B8715889A4E7C864F3' -or
    $manifest.windowsPowerShell2Qualified -ne $false -or
    $manifest.embeddedSshWithoutOpenSsh -ne $true -or
    $manifest.legacyCmdRunner -ne 'RUN-VT7-LEGACY-BASELINE.cmd' -or
    $manifest.sourceGitDirty -ne $false) { throw 'Legacy candidate manifest contract mismatch.' }

$listed = @{}
foreach ($line in ($utf8.GetString($entries['SHA256SUMS.txt']) -split "`r?`n")) {
    if (-not $line) { continue }
    if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw "Malformed SHA256SUMS line: $line" }
    $name = $Matches[2]
    if ($listed.ContainsKey($name) -or -not $entries.ContainsKey($name)) { throw "Unknown or duplicate hash entry: $name" }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actual = [BitConverter]::ToString($sha.ComputeHash($entries[$name])).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
    if ($actual -ne $Matches[1]) { throw "ZIP content hash mismatch: $name" }
    $listed[$name] = $true
}
if ($listed.Count -ne $entries.Count - 1) { throw 'SHA256SUMS does not cover every non-sum ZIP file.' }

$verifyParent = Join-Path $repositoryRoot 'artifacts\vt7\package-verification'
$extractRoot = Join-Path $verifyParent ('legacy Win7 path with spaces ' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
try {
    [IO.Compression.ZipFile]::ExtractToDirectory($archiveFull, $extractRoot)
    if ([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $extractRoot 'VT7.Host.exe')).FileVersion -ne '0.12.5.0') {
        throw 'Extracted legacy candidate host version is not 0.12.5.0.'
    }
    & (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -BinaryDirectory $extractRoot -AllowAnyCpuManaged
    $oldNoPause = $env:VT7_TEST_NO_PAUSE
    $oldOutput = $env:VT7_TEST_OUTPUT_DIRECTORY
    try {
        $env:VT7_TEST_NO_PAUSE = '1'
        $env:VT7_TEST_OUTPUT_DIRECTORY = Join-Path $extractRoot 'verification-logs'
        & (Join-Path $env:SystemRoot 'System32\cmd.exe') /d /c ('"' + (Join-Path $extractRoot 'RUN-VT7-LEGACY-BASELINE.cmd') + '"')
        if ($LASTEXITCODE -ne 0) { throw "Extracted legacy candidate runner failed with exit code $LASTEXITCODE." }
    }
    finally {
        $env:VT7_TEST_NO_PAUSE = $oldNoPause
        $env:VT7_TEST_OUTPUT_DIRECTORY = $oldOutput
    }
}
finally {
    $boundary = [IO.Path]::GetFullPath($verifyParent).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath($extractRoot)
    if (-not $resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing cleanup outside verification directory: $resolved" }
    if (Test-Path -LiteralPath $extractRoot) {
        for ($attempt = 1; $attempt -le 10; ++$attempt) {
            try { Remove-Item -LiteralPath $extractRoot -Recurse -Force; break }
            catch { if ($attempt -eq 10) { throw }; Start-Sleep -Milliseconds 250 }
        }
    }
}

[pscustomobject]@{
    ArchivePath = $archiveFull
    ArchiveSHA256 = (Get-FileHash -LiteralPath $archiveFull -Algorithm SHA256).Hash
    Bytes = (Get-Item -LiteralPath $archiveFull).Length
    Files = $entries.Count
    Verified = $true
}
