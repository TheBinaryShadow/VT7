[CmdletBinding()]
param([string]$PackageName = 'VT7-SSH-Lifecycle-SL01-3-0.2-x64')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageParent = Join-Path $repositoryRoot 'artifacts\vt7\packages'
$baseline = Join-Path $packageParent 'VT7-SSH-Lifecycle-SL01-2-0.4-x64.zip'
$baselineHash = 'AAF77183BF54BA323EC543D9871C575C2EC932DBF3A152370200BCAAA0B1B105'
$packageRoot = Join-Path $packageParent $PackageName
$archivePath = Join-Path $packageParent ($PackageName + '.zip')
$reviewCopy = Join-Path $repositoryRoot ('artifacts\' + $PackageName + '.zip')
$binaryRoot = Join-Path $repositoryRoot 'artifacts\vt7\bin\Release'
if ($PackageName -ne 'VT7-SSH-Lifecycle-SL01-3-0.2-x64') { throw 'Unexpected lifecycle candidate name.' }
foreach ($path in @($packageRoot, $archivePath, $reviewCopy)) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to replace existing candidate: $path" }
}
if ((Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash -ne $baselineHash) { throw 'Accepted baseline archive differs.' }
if ([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $binaryRoot 'VT7.Host.exe')).FileVersion -ne '0.16.0.0') { throw 'Build the 0.16.0 Release host first.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Directory]::CreateDirectory($packageRoot) | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($baseline, $packageRoot)
# Replace the earlier slice's runner only in this fresh stage. The accepted
# native/font/shim/dependency closure and public certificate corpus remain.
foreach ($name in @('RUN-SSH-LIFECYCLE-SL01-2.cmd', 'Test-VT7SshStartupDeadlines.ps1')) {
    $target = [IO.Path]::GetFullPath((Join-Path $packageRoot $name))
    if (-not $target.StartsWith($packageRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Staging boundary violation.' }
    Remove-Item -LiteralPath $target
}
foreach ($name in @('VT7.Host.exe', 'VT7.Host.exe.config')) { Copy-Item -LiteralPath (Join-Path $binaryRoot $name) -Destination $packageRoot }
Copy-Item -LiteralPath (Join-Path $binaryRoot 'VT7.Host.pdb') -Destination (Join-Path $packageRoot 'symbols\VT7.Host.pdb')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Test-VT7SshStartupStalls.ps1') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'src\vt7\packaging\RUN-SSH-LIFECYCLE-SL01-3.cmd') -Destination $packageRoot
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'src\vt7\packaging\SL01-3-README.txt') -Destination (Join-Path $packageRoot 'README.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'src\vt7\packaging\server\VT7-SL01-3-server.py') -Destination (Join-Path $packageRoot 'server')
$manifestPath = Join-Path $packageRoot 'PACKAGE-MANIFEST.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.schema = 'vt7-ssh-lifecycle-sl01-3-package-v1'
$manifest.package = $PackageName
$manifest.createdUtc = [DateTime]::UtcNow.ToString('o')
$manifest.applicationVersion = '0.16.0'
$manifest.scope = 'Real authentication/PTY startup stalls, owned cancellation/close, late replies and typed timeout recovery; paired target acceptance pending; no hard OS resolver completion bound'
$manifest.baselineArchiveSha256 = $baselineHash
$manifest.sourceGitHead = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$manifest.sourceGitDirty = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=all).Count -gt 0
foreach ($property in @('sl01_2TargetAccepted', 'diagnosticNetworkScope', 'sourceInputs')) {
    $manifest.PSObject.Properties.Remove($property)
}
$manifest | Add-Member -NotePropertyName sl01_3TargetAccepted -NotePropertyValue $false
$manifest | Add-Member -NotePropertyName acceptedBaseline -NotePropertyValue 'SL01.2 candidate 0.4; accepted on LEOPARD/NESSY/TURTLE; original issue-time manifest preserved'
$manifest | Add-Member -NotePropertyName fixtureDependency -NotePropertyValue 'Debian server only: python3-paramiko 3.5.1; not shipped and not a Windows runtime dependency'
$manifest | Add-Member -NotePropertyName diagnosticNetworkScope -NotePropertyValue 'portable self-test: loopback only; live mode: opt-in isolated authenticated fault peer'
$sourcePaths = @('src/vt7/Directory.Build.props', 'src/vt7/VT7.Host/App.xaml.cs', 'src/vt7/VT7.Host/SshLifecycleChecks.cs',
    'src/vt7/VT7.Host/SshNetTransport.cs', 'src/vt7/VT7.Host/SshStartupDeadline.cs', 'src/vt7/VT7.Host/H01Checks.cs',
    'src/vt7/VT7.Host/TerminalSession.cs', 'src/vt7/VT7.Host/MainWindow.xaml.cs',
    'src/vt7/VT7.Host/SshOverlayCoordinator.cs', 'tools/Test-VT7SshStartupStalls.ps1', 'tools/Package-VT7SshStartupStalls.ps1',
    'src/vt7/VT7.Host/SessionStreamWindowChecks.cs', 'src/vt7/VT7.Host/SessionOutboundWindowChecks.cs',
    'src/vt7/VT7.Host/SettingsWindowChecks.cs', 'src/vt7/VT7.Host/RepaintWindowChecks.cs',
    'src/vt7/VT7.Host/RecoveryWindowChecks.cs', 'src/vt7/VT7.Host/StabilityWindowChecks.cs',
    'src/vt7/packaging/SL01-3-README.txt', 'src/vt7/packaging/RUN-SSH-LIFECYCLE-SL01-3.cmd', 'src/vt7/packaging/server/VT7-SL01-3-server.py', 'src/vt7/VT7.Host/SshStartupStallChecks.cs')
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
    & $powerShell -Version $engine -NoProfile -ExecutionPolicy Bypass -File (Join-Path $packageRoot 'Test-VT7SshStartupStalls.ps1') -SelfTest -BinaryDirectory $packageRoot -OutputDirectory (Join-Path $testOutput ('PS' + $engine))
    if ($LASTEXITCODE -ne 0) { throw "Packaged lifecycle checks failed on engine $engine." }
}
$oldNoPause = $env:VT7_TEST_NO_PAUSE; $oldOutput = $env:VT7_TEST_OUTPUT_DIRECTORY
try {
    $env:VT7_TEST_NO_PAUSE = '1'; $env:VT7_TEST_OUTPUT_DIRECTORY = Join-Path $testOutput 'CMD'
    & (Join-Path $env:SystemRoot 'System32\cmd.exe') /d /c ('"' + (Join-Path $packageRoot 'RUN-SSH-LIFECYCLE-SL01-3.cmd') + '" --self-test')
    if ($LASTEXITCODE -ne 0) { throw 'Packaged CMD lifecycle checks failed.' }
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
$fresh = Join-Path $packageParent ('SL01.3 independent extraction ' + [Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $fresh)
& $powerShell -Version 2 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fresh 'Test-VT7SshStartupStalls.ps1') -SelfTest -BinaryDirectory $fresh -OutputDirectory (Join-Path $testOutput 'extracted-PS2')
if ($LASTEXITCODE -ne 0) { throw 'Independent extracted PS2/path-with-spaces run failed.' }
Copy-Item -LiteralPath $archivePath -Destination $reviewCopy
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $reviewCopy -Algorithm SHA256).Hash) { throw 'Review ZIP differs.' }
[pscustomobject]@{ ArchivePath = $reviewCopy; ArchiveSHA256 = (Get-FileHash -LiteralPath $reviewCopy -Algorithm SHA256).Hash; Bytes = (Get-Item -LiteralPath $reviewCopy).Length; Files = $seen.Count; TargetAccepted = $false }
