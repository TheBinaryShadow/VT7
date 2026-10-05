[CmdletBinding()]
param([string]$PackageName = 'VT7-KnownHosts-KH01-5-0.2-x64')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$baseline = Join-Path $packageParent 'VT7-Legacy-Win7-0.2-x64.zip'
$baselineHash = '5DB55BB730A242958FDB32EF0DC6F47702BFF43883142435B2E78C27CE9E1450'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')
$reviewCopy = Join-Path $repositoryRoot ('artifacts\' + $PackageName + '.zip')
$binaryRoot = Join-Path $repositoryRoot 'artifacts\vt7\bin\Release'
if ($PackageName -ne 'VT7-KnownHosts-KH01-5-0.2-x64') { throw 'Unexpected certificate candidate name.' }
foreach ($path in @($packageRoot, $archivePath, $reviewCopy)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to replace existing candidate: $path" }
}
if ((Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash -ne $baselineHash) { throw 'Accepted baseline archive differs.' }
if ([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $binaryRoot 'VT7.Host.exe')).FileVersion -ne '0.13.1.0') { throw 'Build the 0.13.1 Release host first.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Directory]::CreateDirectory($packageRoot) | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($baseline, $packageRoot)
# Only remove specifically named superseded launchers from this new staging
# directory. The accepted baseline ZIP and its checkout are never modified.
foreach ($name in @('KH01-4-README.txt', 'LEGACY-0.1-README.txt', 'RUN-KNOWN-HOSTS-KH01-4.cmd',
    'RUN-SSHNET-OVERLAY.cmd', 'Test-VT7H01.ps1', 'Test-VT7KnownHosts.ps1', 'Test-VT7SessionOutbound.ps1',
    'Test-VT7SessionStream.ps1', 'Test-VT7SshNetFoundation.ps1', 'Test-VT7SshOverlay.ps1')) {
    $target = [IO.Path]::GetFullPath((Join-Path $packageRoot $name))
    if (-not $target.StartsWith($packageRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Staging boundary violation.' }
    Remove-Item -LiteralPath $target
}
foreach ($name in @('VT7.Host.exe', 'VT7.Host.exe.config')) { Copy-Item -LiteralPath (Join-Path $binaryRoot $name) -Destination $packageRoot }
Copy-Item -LiteralPath (Join-Path $binaryRoot 'VT7.Host.pdb') -Destination (Join-Path $packageRoot 'symbols\VT7.Host.pdb')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Test-VT7KnownHostsCertificates.ps1') -Destination $packageRoot
foreach ($name in @('RUN-KNOWN-HOSTS-KH01-5.cmd', 'kh01-5-selftest.fixture')) {
    Copy-Item -LiteralPath (Join-Path $repositoryRoot ('src\vt7\packaging\' + $name)) -Destination $packageRoot
}
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'src\vt7\packaging\KH01-5-README.txt') -Destination (Join-Path $packageRoot 'README.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'NOTICE.md') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'src\vt7\packaging\server') -Destination $packageRoot -Recurse

$manifestPath = Join-Path $packageRoot 'PACKAGE-MANIFEST.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.schema = 'vt7-known-hosts-kh01-5-certificate-package-v1'
$manifest.package = $PackageName
$manifest.createdUtc = [DateTime]::UtcNow.ToString('o')
$manifest.applicationVersion = '0.13.1'
$manifest.scope = 'Isolated live SSH.NET host-certificate policy, direct PTY/resize/EOF/reconnect and typed-shell recovery validation'
$manifest.baselineArchiveSha256 = $baselineHash
$manifest.sourceGitHead = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$manifest.sourceGitDirty = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all).Count -gt 0
$manifest | Add-Member -NotePropertyName kh01_5TargetAccepted -NotePropertyValue $false
$manifest | Add-Member -NotePropertyName nativeBaselineVersion -NotePropertyValue '0.12.3'
$manifest | Add-Member -NotePropertyName isolatedDiagnosticTrustStore -NotePropertyValue $true
$manifest | Add-Member -NotePropertyName certificateCaseCount -NotePropertyValue 9
$sourcePaths = @('NOTICE.md', 'src/vt7/Directory.Build.props', 'src/vt7/VT7.Host/App.xaml.cs', 'src/vt7/VT7.Host/KnownHostsCertificateChecks.cs',
    'src/vt7/VT7.Host/SshNetTransport.cs', 'src/vt7/VT7.Host/SshOverlayCoordinator.cs',
    'tools/Test-VT7KnownHostsCertificates.ps1', 'tools/New-VT7CertificateSelfTestFixture.ps1', 'tools/Package-VT7KnownHostsCertificates.ps1',
    'src/vt7/packaging/KH01-5-README.txt', 'src/vt7/packaging/RUN-KNOWN-HOSTS-KH01-5.cmd',
    'src/vt7/packaging/kh01-5-selftest.fixture', 'src/vt7/packaging/server/VT7-KH01-5-server.sh', 'src/vt7/packaging/server/VT7-KH01-5-audit.py')
$sourceInputs = @($sourcePaths | ForEach-Object { [ordered]@{ path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $_) -Algorithm SHA256).Hash } })
$manifest | Add-Member -NotePropertyName sourceInputs -NotePropertyValue $sourceInputs
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 10), $utf8)
$hashLines = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object FullName | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
})
[IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), $hashLines, $utf8)
& (Join-Path $PSScriptRoot 'Verify-VT7.ps1') -Configuration Release -BinaryDirectory $packageRoot -AllowAnyCpuManaged

$testOutput = Join-Path $packageParent ($PackageName + '-local-logs')
$powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
foreach ($engine in @('5', '2')) {
    & $powerShell -Version $engine -NoProfile -ExecutionPolicy Bypass -File (Join-Path $packageRoot 'Test-VT7KnownHostsCertificates.ps1') -BinaryDirectory $packageRoot -OutputDirectory (Join-Path $testOutput ('PS' + $engine)) -SelfTest
    if ($LASTEXITCODE -ne 0) { throw "Packaged self-test failed on engine $engine." }
}
$oldNoPause = $env:VT7_TEST_NO_PAUSE; $oldOutput = $env:VT7_TEST_OUTPUT_DIRECTORY
try {
    $env:VT7_TEST_NO_PAUSE = '1'; $env:VT7_TEST_OUTPUT_DIRECTORY = Join-Path $testOutput 'CMD'
    & (Join-Path $env:SystemRoot 'System32\cmd.exe') /d /c ('"' + (Join-Path $packageRoot 'RUN-KNOWN-HOSTS-KH01-5.cmd') + '" --self-test')
    if ($LASTEXITCODE -ne 0) { throw 'Packaged CMD self-test failed.' }
}
finally { $env:VT7_TEST_NO_PAUSE = $oldNoPause; $env:VT7_TEST_OUTPUT_DIRECTORY = $oldOutput }
[IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @{}
foreach ($file in Get-ChildItem -LiteralPath $packageRoot -Recurse -File) {
    $expected[$file.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$seen = @{}; $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $name = $entry.FullName.Replace('\', '/')
        if ($name.StartsWith('/') -or $name.Split('/') -contains '..' -or $seen.ContainsKey($name) -or -not $expected.ContainsKey($name)) { throw 'Unsafe or unexpected ZIP entry.' }
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne $expected[$name]) { throw 'ZIP entry hash differs.' }
        $seen[$name] = $true
    }
}
finally { $archive.Dispose() }
if ($seen.Count -ne $expected.Count) { throw 'ZIP is missing staged files.' }
$fresh = Join-Path $packageParent ('KH01.5 independent extraction ' + [Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $fresh)
& $powerShell -Version 2 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fresh 'Test-VT7KnownHostsCertificates.ps1') -BinaryDirectory $fresh -OutputDirectory (Join-Path $testOutput 'extracted-PS2') -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Independent extracted PS2/path-with-spaces run failed.' }
Copy-Item -LiteralPath $archivePath -Destination $reviewCopy
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $reviewCopy -Algorithm SHA256).Hash) { throw 'Review ZIP differs.' }
[pscustomobject]@{ ArchivePath = $reviewCopy; ArchiveSHA256 = (Get-FileHash -LiteralPath $reviewCopy -Algorithm SHA256).Hash; Bytes = (Get-Item -LiteralPath $reviewCopy).Length; Files = $seen.Count; TargetAccepted = $false }
