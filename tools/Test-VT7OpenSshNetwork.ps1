[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ServerHostName,
    [ValidateRange(1, 65535)][int]$Port = 22,
    [Parameter(Mandatory=$true)][string]$UserName,
    [Parameter(Mandatory=$true)][string]$IdentityFile,
    [Parameter(Mandatory=$true)][string]$ExpectedHostKeyFingerprint,
    [string]$SshPath,
    [string]$OutputRoot,
    [string]$RemotePython = '/usr/bin/python3'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$expectedClientSha256 = '6890C128C86CC2C38AAD9FCB32A82B851FF3D38C714A1F656B8E445D7CD5E1C6'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$reportParent = if ($OutputRoot) { [IO.Path]::GetFullPath($OutputRoot) } else { Join-Path $repositoryRoot 'artifacts\vt7\reports\S00' }
$runRoot = Join-Path $reportParent ('openssh-s00-network-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$utf8 = New-Object Text.UTF8Encoding($false)

function Get-Sha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-BytesSha256Hex {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-', '') }
    finally { $sha.Dispose() }
}

function ConvertTo-NativeArgument {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Value)
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($slashes * 2) + 1)))
            [void]$builder.Append('"')
        }
        else {
            if ($slashes -gt 0) { [void]$builder.Append(('\' * $slashes)) }
            [void]$builder.Append($character)
        }
        $slashes = 0
    }
    if ($slashes -gt 0) { [void]$builder.Append(('\' * ($slashes * 2))) }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-RawProcess {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$FileName,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string[]]$RecordedArguments,
        [Parameter(Mandatory=$true)][string]$OutputDirectory,
        [ValidateRange(1, 120)][int]$TimeoutSeconds = 30,
        [ValidateRange(0, 120000)][int]$CancelAfterMilliseconds = 0,
        [byte[]]$StandardInputBytes = @()
    )
    $caseRoot = Join-Path $OutputDirectory $Name
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $stdoutPath = Join-Path $caseRoot 'stdout.bin'
    $stderrPath = Join-Path $caseRoot 'stderr.bin'
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FileName
    $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['SSH_ASKPASS_REQUIRE'] = 'never'
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $stdoutStream = $null
    $stderrStream = $null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $cancelRequested = $false
    $timedOut = $false
    try {
        if (-not $process.Start()) { throw "S00 network process did not start: $Name" }
        $processId = $process.Id
        $stdoutStream = New-Object IO.FileStream($stdoutPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $stderrStream = New-Object IO.FileStream($stderrPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        $stdoutCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
        $stderrCopy = $process.StandardError.BaseStream.CopyToAsync($stderrStream)
        if ($StandardInputBytes.Count -gt 0) {
            $process.StandardInput.BaseStream.Write($StandardInputBytes, 0, $StandardInputBytes.Count)
            $process.StandardInput.BaseStream.Flush()
        }
        $process.StandardInput.Close()
        while (-not $process.WaitForExit(50)) {
            if ($CancelAfterMilliseconds -gt 0 -and -not $cancelRequested -and $watch.ElapsedMilliseconds -ge $CancelAfterMilliseconds) {
                $cancelRequested = $true
                try { $process.Kill() } catch {}
            }
            if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                $timedOut = $true
                try { $process.Kill() } catch {}
                break
            }
        }
        $process.WaitForExit()
        [void]$stdoutCopy.GetAwaiter().GetResult()
        [void]$stderrCopy.GetAwaiter().GetResult()
        $stdoutStream.Flush(); $stderrStream.Flush()
        $stdoutStream.Dispose(); $stderrStream.Dispose()
        $stdoutStream = $null; $stderrStream = $null
        $watch.Stop()
        $result = [ordered]@{
            schema = 'vt7-s00-network-process-case-v1'
            name = $Name
            fileName = [IO.Path]::GetFileName($FileName)
            arguments = $RecordedArguments
            processId = $processId
            exitCode = $process.ExitCode
            elapsedMilliseconds = $watch.ElapsedMilliseconds
            cancelAfterMilliseconds = $CancelAfterMilliseconds
            cancelRequested = $cancelRequested
            timedOut = $timedOut
            standardInputBytes = $StandardInputBytes.Count
            standardOutputBytes = (Get-Item -LiteralPath $stdoutPath).Length
            standardErrorBytes = (Get-Item -LiteralPath $stderrPath).Length
            standardOutputSha256 = Get-Sha256Hex $stdoutPath
            standardErrorSha256 = Get-Sha256Hex $stderrPath
        }
        [IO.File]::WriteAllText((Join-Path $caseRoot 'result.json'), ($result | ConvertTo-Json -Depth 8), $utf8)
        return [pscustomobject]$result
    }
    finally {
        if ($stdoutStream) { $stdoutStream.Dispose() }
        if ($stderrStream) { $stderrStream.Dispose() }
        $process.Dispose()
    }
}

function Test-BytesEqual {
    param([byte[]]$Left, [byte[]]$Right)
    if ($Left.Length -ne $Right.Length) { return $false }
    for ($index = 0; $index -lt $Left.Length; $index++) { if ($Left[$index] -ne $Right[$index]) { return $false } }
    return $true
}

function ConvertTo-RedactedText {
    param([string]$Text)
    $result = $Text
    foreach ($item in @(
        [pscustomobject]@{ Value = $IdentityFile; Replacement = '<identity>' },
        [pscustomobject]@{ Value = ($UserName + '@' + $ServerHostName); Replacement = '<user>@<server>' },
        [pscustomobject]@{ Value = $ServerHostName; Replacement = '<server>' },
        [pscustomobject]@{ Value = $UserName; Replacement = '<user>' }
    )) {
        if ($item.Value) { $result = $result.Replace($item.Value, $item.Replacement) }
    }
    return $result
}

function Write-RedactedTextCase {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)]$Result,
        [Parameter(Mandatory=$true)][string]$SourceCaseRoot,
        [Parameter(Mandatory=$true)][string[]]$RecordedArguments
    )
    $caseRoot = Join-Path $runRoot $Name
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $stdoutText = ConvertTo-RedactedText ($utf8.GetString([IO.File]::ReadAllBytes((Join-Path $SourceCaseRoot 'stdout.bin'))))
    $stderrText = ConvertTo-RedactedText ($utf8.GetString([IO.File]::ReadAllBytes((Join-Path $SourceCaseRoot 'stderr.bin'))))
    $stdoutPath = Join-Path $caseRoot 'stdout.txt'
    $stderrPath = Join-Path $caseRoot 'stderr.txt'
    [IO.File]::WriteAllText($stdoutPath, $stdoutText, $utf8)
    [IO.File]::WriteAllText($stderrPath, $stderrText, $utf8)
    $safeResult = [ordered]@{
        schema = 'vt7-s00-network-redacted-text-case-v1'
        name = $Name
        fileName = 'ssh.exe'
        arguments = $RecordedArguments
        exitCode = $Result.exitCode
        elapsedMilliseconds = $Result.elapsedMilliseconds
        cancelAfterMilliseconds = $Result.cancelAfterMilliseconds
        cancelRequested = $Result.cancelRequested
        timedOut = $Result.timedOut
        standardInputBytes = $Result.standardInputBytes
        redactedStandardOutputBytes = (Get-Item -LiteralPath $stdoutPath).Length
        redactedStandardErrorBytes = (Get-Item -LiteralPath $stderrPath).Length
        redactedStandardOutputSha256 = Get-Sha256Hex $stdoutPath
        redactedStandardErrorSha256 = Get-Sha256Hex $stderrPath
    }
    [IO.File]::WriteAllText((Join-Path $caseRoot 'result.json'), ($safeResult | ConvertTo-Json -Depth 8), $utf8)
}

function Copy-VerifiedRawCase {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$SourceCaseRoot
    )
    $caseRoot = Join-Path $runRoot $Name
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    foreach ($fileName in @('stdout.bin', 'stderr.bin', 'result.json')) {
        [IO.File]::Copy((Join-Path $SourceCaseRoot $fileName), (Join-Path $caseRoot $fileName), $false)
    }
}

function Get-BaseArguments {
    param([string]$KnownHostsPath)
    return @(
        '-F', 'NUL', '-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes',
        '-o', 'IdentityAgent=none', '-o', 'PreferredAuthentications=publickey',
        '-o', 'PasswordAuthentication=no', '-o', 'KbdInteractiveAuthentication=no',
        '-o', 'PubkeyAuthentication=yes', '-o', 'CanonicalizeHostname=no',
        '-o', 'CheckHostIP=no', '-o', 'StrictHostKeyChecking=yes',
        '-o', 'GlobalKnownHostsFile=NUL', '-o', ('UserKnownHostsFile=' + $KnownHostsPath),
        '-o', 'UpdateHostKeys=no', '-o', 'ForwardAgent=no', '-o', 'ForwardX11=no',
        '-o', 'ClearAllForwardings=yes', '-o', 'PermitLocalCommand=no',
        '-o', 'LogLevel=ERROR', '-o', 'HostKeyAlgorithms=ssh-ed25519',
        '-i', $IdentityFile, '-p', $Port.ToString([Globalization.CultureInfo]::InvariantCulture)
    )
}

function Get-RecordedBaseArguments {
    return @(
        '-F', 'NUL', '-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes',
        '-o', 'IdentityAgent=none', '-o', 'PreferredAuthentications=publickey',
        '-o', 'PasswordAuthentication=no', '-o', 'KbdInteractiveAuthentication=no',
        '-o', 'PubkeyAuthentication=yes', '-o', 'CanonicalizeHostname=no',
        '-o', 'CheckHostIP=no', '-o', 'StrictHostKeyChecking=yes',
        '-o', 'GlobalKnownHostsFile=NUL', '-o', 'UserKnownHostsFile=<ephemeral>',
        '-o', 'UpdateHostKeys=no', '-o', 'ForwardAgent=no', '-o', 'ForwardX11=no',
        '-o', 'ClearAllForwardings=yes', '-o', 'PermitLocalCommand=no',
        '-o', 'LogLevel=ERROR', '-o', 'HostKeyAlgorithms=ssh-ed25519',
        '-i', '<identity>', '-p', '<port>'
    )
}

if (-not $ServerHostName.Trim()) { throw 'ServerHostName cannot be empty.' }
if (-not $UserName.Trim()) { throw 'UserName cannot be empty.' }
if ($ExpectedHostKeyFingerprint -notmatch '^SHA256:[A-Za-z0-9+/]{43}=?$') { throw 'ExpectedHostKeyFingerprint must be an OpenSSH SHA256 fingerprint.' }
if ($RemotePython -notmatch '^/[A-Za-z0-9_./-]+$') { throw 'RemotePython must be an absolute POSIX path without spaces.' }
$IdentityFile = [IO.Path]::GetFullPath($IdentityFile)
if (-not (Test-Path -LiteralPath $IdentityFile -PathType Leaf)) { throw "Identity file was not found: $IdentityFile" }
if (-not $SshPath) {
    $programFilesCandidate = Join-Path $env:ProgramFiles 'OpenSSH\ssh.exe'
    if (Test-Path -LiteralPath $programFilesCandidate -PathType Leaf) { $SshPath = $programFilesCandidate }
    else {
        $command = Get-Command ssh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $SshPath = $command.Source }
    }
}
if (-not $SshPath) { throw 'ssh.exe was not found under Program Files or on PATH.' }
$SshPath = [IO.Path]::GetFullPath($SshPath)
if ((Get-Sha256Hex $SshPath) -ne $expectedClientSha256) { throw 'ssh.exe does not match the accepted Windows 7 S00 client.' }
$sshKeyscanPath = Join-Path ([IO.Path]::GetDirectoryName($SshPath)) 'ssh-keyscan.exe'
if (-not (Test-Path -LiteralPath $sshKeyscanPath -PathType Leaf)) { throw 'ssh-keyscan.exe is missing beside the accepted client.' }

New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$scratchRoot = Join-Path ([IO.Path]::GetTempPath()) ('vt7-s00-network-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratchRoot | Out-Null
$target = $UserName + '@' + $ServerHostName
$recordedTarget = '<user>@<server>'
$hostTrust = $null
$negotiation = $null
try {
    $scanResult = @(Invoke-RawProcess -Name 'host-key-scan' -FileName $sshKeyscanPath -Arguments @('-T', '5', '-p', $Port.ToString(), '-t', 'ed25519', $ServerHostName) -RecordedArguments @('-T', '5', '-p', '<port>', '-t', 'ed25519', '<server>') -OutputDirectory $scratchRoot -TimeoutSeconds 10)[-1]
    $scanText = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $scratchRoot 'host-key-scan\stdout.bin')))
    $scanLine = @($scanText -split "`r?`n" | Where-Object { $_ -match '^\S+\s+ssh-ed25519\s+[A-Za-z0-9+/=]+(?:\s.*)?$' } | Select-Object -First 1)
    if ($scanResult.exitCode -ne 0 -or $scanLine.Count -ne 1) { throw 'The server did not return one usable Ed25519 host key.' }
    $parts = $scanLine[0] -split '\s+'
    [byte[]]$hostKeyBlob = [Convert]::FromBase64String($parts[2])
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actualFingerprint = 'SHA256:' + [Convert]::ToBase64String($sha.ComputeHash($hostKeyBlob)).TrimEnd('=') }
    finally { $sha.Dispose() }
    if ($actualFingerprint -ne $ExpectedHostKeyFingerprint.TrimEnd('=')) { throw 'The scanned Ed25519 host key does not match the independently supplied fingerprint.' }

    $emptyKnownHosts = Join-Path $scratchRoot 'known-hosts-empty'
    $validKnownHosts = Join-Path $scratchRoot 'known-hosts-valid'
    $changedKnownHosts = Join-Path $scratchRoot 'known-hosts-changed'
    [IO.File]::WriteAllBytes($emptyKnownHosts, @())
    [IO.File]::WriteAllText($validKnownHosts, $scanLine[0] + "`n", $utf8)
    [byte[]]$changedBlob = $hostKeyBlob.Clone()
    $changedBlob[$changedBlob.Length - 1] = $changedBlob[$changedBlob.Length - 1] -bxor 1
    $changedLine = $parts[0] + ' ' + $parts[1] + ' ' + [Convert]::ToBase64String($changedBlob)
    [IO.File]::WriteAllText($changedKnownHosts, $changedLine + "`n", $utf8)

    $unknownArgs = @(Get-BaseArguments $emptyKnownHosts) + @('-T', $target, '/bin/true')
    $unknownRecorded = @(Get-RecordedBaseArguments) + @('-T', $recordedTarget, '/bin/true')
    $unknown = @(Invoke-RawProcess -Name 'trust-unknown' -FileName $SshPath -Arguments $unknownArgs -RecordedArguments $unknownRecorded -OutputDirectory $scratchRoot -TimeoutSeconds 15)[-1]
    $unknownError = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $scratchRoot 'trust-unknown\stderr.bin')))
    if ($unknown.exitCode -ne 255 -or $unknown.standardOutputBytes -ne 0 -or $unknownError -notmatch 'Host key verification failed') { throw 'Unknown-host strict rejection did not follow the required channel and exit contract.' }

    $changedArgs = @(Get-BaseArguments $changedKnownHosts) + @('-T', $target, '/bin/true')
    $changedRecorded = @(Get-RecordedBaseArguments) + @('-T', $recordedTarget, '/bin/true')
    $changed = @(Invoke-RawProcess -Name 'trust-changed' -FileName $SshPath -Arguments $changedArgs -RecordedArguments $changedRecorded -OutputDirectory $scratchRoot -TimeoutSeconds 15)[-1]
    $changedError = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $scratchRoot 'trust-changed\stderr.bin')))
    if ($changed.exitCode -ne 255 -or $changed.standardOutputBytes -ne 0 -or $changedError -notmatch 'REMOTE HOST IDENTIFICATION HAS CHANGED') { throw 'Changed-host strict rejection did not follow the required channel and exit contract.' }
    $hostTrust = [ordered]@{
        scannedEd25519FingerprintMatchedOutOfBandValue = $true
        unknownHostRejected = $true
        unknownHostExitCode = $unknown.exitCode
        unknownHostDiagnostic = 'Host key verification failed.'
        changedHostRejected = $true
        changedHostExitCode = $changed.exitCode
        changedHostDiagnostic = 'REMOTE HOST IDENTIFICATION HAS CHANGED; host key verification failed.'
        hostNameRecorded = $false
        hostKeyRecorded = $false
        hostKeyFingerprintRecorded = $false
    }

    $base = @(Get-BaseArguments $validKnownHosts)
    $recordedBase = @(Get-RecordedBaseArguments)
    $capsCode = "import os,shutil;print('VT7_CAPS python=%d sh=%d stty=%d bash=%d' % (os.path.exists('$RemotePython'),os.path.exists('/bin/sh'),shutil.which('stty') is not None,os.path.exists('/bin/bash')))"
    $capsCommand = $RemotePython + ' -c "' + $capsCode + '"'
    $caps = @(Invoke-RawProcess -Name 'server-capabilities' -FileName $SshPath -Arguments ($base + @('-T', $target, $capsCommand)) -RecordedArguments ($recordedBase + @('-T', $recordedTarget, '<python capability probe>')) -OutputDirectory $scratchRoot -TimeoutSeconds 20)[-1]
    $capsCaseRoot = Join-Path $scratchRoot 'server-capabilities'
    $capsBytes = [IO.File]::ReadAllBytes((Join-Path $capsCaseRoot 'stdout.bin'))
    $capsText = $utf8.GetString($capsBytes).Trim()
    if ($caps.exitCode -ne 0 -or $caps.standardErrorBytes -ne 0 -or $capsText -ne 'VT7_CAPS python=1 sh=1 stty=1 bash=1') { throw 'The controlled server does not satisfy the required Debian test capabilities.' }
    Copy-VerifiedRawCase -Name 'server-capabilities' -SourceCaseRoot $capsCaseRoot

    $unicodeFixture = 'UNICODE=' + [char]0x010C + [char]0x0107 + [char]0x017D + [char]0x017E + [char]0x0160 + [char]0x0161 + [char]0x0110 + [char]0x0111 + ' e' + [char]0x0301 + ' ' + [char]0x4E2D
    $stdoutFixture = $utf8.GetBytes(('VT7-S00-NONPTY' + "`r`n" + 'ESC=' + [char]27 + '[31mred' + [char]27 + '[0m' + "`n" + 'HR=CcZzSsDd' + "`n" + $unicodeFixture + "`n" + 'NUL=' + [char]0 + ':END' + "`r`n"))
    $stderrFixture = $utf8.GetBytes("VT7-S00-REMOTE-STDERR`n")
    $stdoutHex = [BitConverter]::ToString($stdoutFixture).Replace('-', '').ToLowerInvariant()
    $stderrHex = [BitConverter]::ToString($stderrFixture).Replace('-', '').ToLowerInvariant()
    $exactCode = "import sys;sys.stdout.buffer.write(bytes.fromhex('$stdoutHex'));sys.stdout.buffer.flush();sys.stderr.buffer.write(bytes.fromhex('$stderrHex'));sys.stderr.buffer.flush();raise SystemExit(23)"
    $exactCommand = $RemotePython + ' -c "' + $exactCode + '"'
    $exact = @(Invoke-RawProcess -Name 'nonpty-exact-bytes' -FileName $SshPath -Arguments ($base + @('-T', $target, $exactCommand)) -RecordedArguments ($recordedBase + @('-T', $recordedTarget, '<exact byte fixture>')) -OutputDirectory $scratchRoot -TimeoutSeconds 20)[-1]
    $exactCaseRoot = Join-Path $scratchRoot 'nonpty-exact-bytes'
    $actualStdout = [IO.File]::ReadAllBytes((Join-Path $exactCaseRoot 'stdout.bin'))
    $actualStderr = [IO.File]::ReadAllBytes((Join-Path $exactCaseRoot 'stderr.bin'))
    if ($exact.exitCode -ne 23 -or -not (Test-BytesEqual $actualStdout $stdoutFixture) -or -not (Test-BytesEqual $actualStderr $stderrFixture)) { throw 'Non-PTY exact-byte, channel or remote-exit propagation failed.' }
    Copy-VerifiedRawCase -Name 'nonpty-exact-bytes' -SourceCaseRoot $exactCaseRoot

    $drainLength = 131071
    [byte[]]$drainExpected = New-Object byte[] $drainLength
    for ($i = 0; $i -lt $drainLength; $i++) { $drainExpected[$i] = [byte]($i % 251) }
    $drainCode = "import sys;sys.stdout.buffer.write(bytes((i%251 for i in range($drainLength))));sys.stdout.buffer.flush();raise SystemExit(37)"
    $drainCommand = $RemotePython + ' -c "' + $drainCode + '"'
    $drain = @(Invoke-RawProcess -Name 'nonpty-final-drain' -FileName $SshPath -Arguments ($base + @('-T', $target, $drainCommand)) -RecordedArguments ($recordedBase + @('-T', $recordedTarget, '<131071-byte drain fixture>')) -OutputDirectory $scratchRoot -TimeoutSeconds 20)[-1]
    $drainCaseRoot = Join-Path $scratchRoot 'nonpty-final-drain'
    $drainActual = [IO.File]::ReadAllBytes((Join-Path $drainCaseRoot 'stdout.bin'))
    if ($drain.exitCode -ne 37 -or $drain.standardErrorBytes -ne 0 -or -not (Test-BytesEqual $drainActual $drainExpected)) { throw 'Final output drain before remote exit failed.' }
    Copy-VerifiedRawCase -Name 'nonpty-final-drain' -SourceCaseRoot $drainCaseRoot

    $ptyCode = "import os,sys;s=os.get_terminal_size(0);print('VT7_PTY cols=%d rows=%d stdin=%d stdout=%d stderr=%d term=%s' % (s.columns,s.lines,os.isatty(0),os.isatty(1),os.isatty(2),os.environ.get('TERM','')));sys.stdout.flush()"
    $ptyCommand = $RemotePython + ' -c "' + $ptyCode + '"'
    $ptyRecordedArguments = $recordedBase + @('-tt', $recordedTarget, '<PTY size probe>')
    $pty = @(Invoke-RawProcess -Name 'forced-pty-initial-size' -FileName $SshPath -Arguments ($base + @('-tt', $target, $ptyCommand)) -RecordedArguments $ptyRecordedArguments -OutputDirectory $scratchRoot -TimeoutSeconds 20)[-1]
    $ptyScratchRoot = Join-Path $scratchRoot 'forced-pty-initial-size'
    $ptyText = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $ptyScratchRoot 'stdout.bin')))
    $ptyMatch = [regex]::Match($ptyText, 'VT7_PTY cols=(\d+) rows=(\d+) stdin=(\d+) stdout=(\d+) stderr=(\d+) term=([^\r\n]*)')
    if ($pty.exitCode -ne 0 -or -not $ptyMatch.Success) { throw 'Forced PTY allocation or initial-size report failed.' }
    $ptyResult = [ordered]@{
        allocated = $true
        columns = [int]$ptyMatch.Groups[1].Value
        rows = [int]$ptyMatch.Groups[2].Value
        stdinIsTty = ($ptyMatch.Groups[3].Value -eq '1')
        stdoutIsTty = ($ptyMatch.Groups[4].Value -eq '1')
        stderrIsTty = ($ptyMatch.Groups[5].Value -eq '1')
        term = $ptyMatch.Groups[6].Value
        clientDiagnostic = ConvertTo-RedactedText ($utf8.GetString([IO.File]::ReadAllBytes((Join-Path $ptyScratchRoot 'stderr.bin'))).Trim())
    }
    Write-RedactedTextCase -Name 'forced-pty-initial-size' -Result $pty -SourceCaseRoot $ptyScratchRoot -RecordedArguments $ptyRecordedArguments

    $activeCode = "import os,time;[(os.write(1,b'VT7-ACTIVE\n'),time.sleep(0.01)) for _ in iter(int,1)]"
    $activeCommand = $RemotePython + ' -c "' + $activeCode + '"'
    $activeRecordedArguments = $recordedBase + @('-T', $recordedTarget, '<active output until cancellation>')
    $active = @(Invoke-RawProcess -Name 'active-output-cancel' -FileName $SshPath -Arguments ($base + @('-T', $target, $activeCommand)) -RecordedArguments $activeRecordedArguments -OutputDirectory $scratchRoot -TimeoutSeconds 10 -CancelAfterMilliseconds 750)[-1]
    if (-not $active.cancelRequested -or $active.timedOut -or $active.standardOutputBytes -eq 0 -or $active.elapsedMilliseconds -ge 5000) { throw 'Active-output cancellation did not meet the bounded contract.' }
    Write-RedactedTextCase -Name 'active-output-cancel' -Result $active -SourceCaseRoot (Join-Path $scratchRoot 'active-output-cancel') -RecordedArguments $activeRecordedArguments

    $negotiationArgs = $base + @('-vv', '-T', $target, '/bin/true')
    $negotiationRecorded = $recordedBase + @('-vv', '-T', $recordedTarget, '/bin/true')
    $negotiationCase = @(Invoke-RawProcess -Name 'negotiation' -FileName $SshPath -Arguments $negotiationArgs -RecordedArguments $negotiationRecorded -OutputDirectory $scratchRoot -TimeoutSeconds 20)[-1]
    $negotiationText = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $scratchRoot 'negotiation\stderr.bin')))
    if ($negotiationCase.exitCode -ne 0) { throw 'Negotiated-algorithm capture failed.' }
    $kexMatch = [regex]::Match($negotiationText, 'kex: algorithm: ([^\r\n]+)')
    $hostKeyMatch = [regex]::Match($negotiationText, 'kex: host key algorithm: ([^\r\n]+)')
    $serverCipherMatch = [regex]::Match($negotiationText, 'kex: server->client cipher: (\S+) MAC: (\S+) compression: (\S+)')
    $clientCipherMatch = [regex]::Match($negotiationText, 'kex: client->server cipher: (\S+) MAC: (\S+) compression: (\S+)')
    if (-not $kexMatch.Success -or -not $hostKeyMatch.Success -or -not $serverCipherMatch.Success -or -not $clientCipherMatch.Success) { throw 'Could not extract the negotiated algorithms from OpenSSH diagnostics.' }
    $negotiation = [ordered]@{
        keyExchange = $kexMatch.Groups[1].Value.Trim()
        hostKey = $hostKeyMatch.Groups[1].Value.Trim()
        serverToClientCipher = $serverCipherMatch.Groups[1].Value
        serverToClientMac = $serverCipherMatch.Groups[2].Value
        serverToClientCompression = $serverCipherMatch.Groups[3].Value
        clientToServerCipher = $clientCipherMatch.Groups[1].Value
        clientToServerMac = $clientCipherMatch.Groups[2].Value
        clientToServerCompression = $clientCipherMatch.Groups[3].Value
    }

    $manifest = [ordered]@{
        schema = 'vt7-openssh-s00-network-v1'
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        complete = $true
        scope = 'Controlled Debian OpenSSH server trust, key authentication, raw bytes, PTY allocation, cancellation and drain'
        privacy = [ordered]@{
            serverHostNameRecorded = $false
            userNameRecorded = $false
            portRecorded = $false
            identityPathRecorded = $false
            privateKeyCopiedOrHashed = $false
            hostKeyOrFingerprintRecorded = $false
            passwordRead = $false
        }
        client = [ordered]@{
            bytes = (Get-Item -LiteralPath $SshPath).Length
            sha256 = Get-Sha256Hex $SshPath
            version = [Diagnostics.FileVersionInfo]::GetVersionInfo($SshPath).ProductVersion
            pinnedFromAcceptedPreflight = $true
        }
        hostTrust = $hostTrust
        publicKeyAuthentication = [ordered]@{ batchMode = $true; identitiesOnly = $true; passwordFallbackDisabled = $true; accepted = $true }
        serverCapabilities = [ordered]@{ python3 = $true; sh = $true; stty = $true; bash = $true }
        negotiatedAlgorithms = $negotiation
        nonPtyExactBytes = [ordered]@{
            outputBytes = $stdoutFixture.Length
            outputSha256 = Get-BytesSha256Hex $stdoutFixture
            errorBytes = $stderrFixture.Length
            errorSha256 = Get-BytesSha256Hex $stderrFixture
            remoteExitCode = 23
            accepted = $true
        }
        finalDrain = [ordered]@{ bytes = $drainLength; sha256 = Get-BytesSha256Hex $drainExpected; remoteExitCode = 37; accepted = $true }
        forcedPty = $ptyResult
        activeOutputCancellation = [ordered]@{ bytesBeforeCancel = $active.standardOutputBytes; elapsedMilliseconds = $active.elapsedMilliseconds; accepted = $true }
        disposition = 'S00 complete: exact Microsoft 10.0p2 source rejects redirected interactive PTY geometry; external client remains accepted for non-PTY command transport'
        successor = 'SSH.NET 2026.0.0 is approved for a separately versioned S01 diagnostic'
    }
    [IO.File]::WriteAllText((Join-Path $runRoot 'manifest.json'), ($manifest | ConvertTo-Json -Depth 12), $utf8)
}
finally {
    if (Test-Path -LiteralPath $scratchRoot) { [IO.Directory]::Delete($scratchRoot, $true) }
}

Write-Host "S00 controlled-server network characterization passed: $runRoot"
[pscustomobject]@{ Run = $runRoot; ClientSHA256 = $expectedClientSha256; PseudoTerminalColumns = $ptyResult.columns; PseudoTerminalRows = $ptyResult.rows; S00Complete = $true }
