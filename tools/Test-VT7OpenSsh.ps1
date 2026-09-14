[CmdletBinding()]
param(
    [string]$SshPath,
    [string]$OutputRoot,
    [string]$ExpectedSshSha256,
    [string]$ExpectedVersionPattern
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$reportParent = if ($OutputRoot) {
    [IO.Path]::GetFullPath($OutputRoot)
}
else {
    Join-Path $repositoryRoot 'artifacts\vt7\reports\S00'
}
$runRoot = Join-Path $reportParent ('openssh-s00-preflight-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))

function Get-Sha256Hex {
    param([Parameter(Mandatory=$true)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '')
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function ConvertTo-NativeArgument {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Value)

    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $slashes++
            continue
        }
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

    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $stdoutStream = $null
    $stderrStream = $null
    $stdoutCopy = $null
    $stderrCopy = $null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $cancelRequested = $false
    $timedOut = $false

    try {
        if (-not $process.Start()) { throw "S00 process did not start: $Name" }
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
                $process.Kill()
            }
            if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                $timedOut = $true
                $process.Kill()
                break
            }
        }
        $process.WaitForExit()
        $stdoutCopy.GetAwaiter().GetResult()
        $stderrCopy.GetAwaiter().GetResult()
        $stdoutStream.Flush()
        $stderrStream.Flush()
        $stdoutStream.Dispose()
        $stderrStream.Dispose()
        $stdoutStream = $null
        $stderrStream = $null
        $watch.Stop()

        $result = [ordered]@{
            schema = 'vt7-s00-process-case-v1'
            name = $Name
            fileName = $FileName
            arguments = $Arguments
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
        $utf8 = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText((Join-Path $caseRoot 'result.json'), ($result | ConvertTo-Json -Depth 6), $utf8)
        return [pscustomobject]$result
    }
    finally {
        if ($stdoutStream) { $stdoutStream.Dispose() }
        if ($stderrStream) { $stderrStream.Dispose() }
        $process.Dispose()
    }
}

if (-not $SshPath) {
    $command = Get-Command ssh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw 'ssh.exe was not found. Pass -SshPath explicitly.' }
    $SshPath = $command.Source
}
$SshPath = [IO.Path]::GetFullPath($SshPath)
if (-not (Test-Path -LiteralPath $SshPath -PathType Leaf)) {
    throw "ssh.exe was not found: $SshPath"
}

$sshHash = Get-Sha256Hex $SshPath
if ($ExpectedSshSha256 -and $sshHash -ne $ExpectedSshSha256.ToUpperInvariant()) {
    throw "ssh.exe SHA256 mismatch. Expected $ExpectedSshSha256; found $sshHash"
}

New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$clientVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($SshPath)
$signatureStatus = 'Unavailable'
$signerSubject = $null
try {
    $signature = Get-AuthenticodeSignature -LiteralPath $SshPath -ErrorAction Stop
    $signatureStatus = $signature.Status.ToString()
    if ($signature.SignerCertificate) { $signerSubject = $signature.SignerCertificate.Subject }
}
catch {
    $signatureStatus = 'Unavailable: ' + $_.Exception.Message
}

$versionItems = @(Invoke-RawProcess -Name 'version' -FileName $SshPath -Arguments @('-V') -OutputDirectory $runRoot)
$version = $versionItems[-1]
$versionText = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $runRoot 'version\stderr.bin'))).Trim()
if ($version.exitCode -ne 0 -or $version.standardOutputBytes -ne 0 -or $version.standardErrorBytes -eq 0) {
    throw 'OpenSSH version routing was not stderr-only with a successful exit.'
}
if ($ExpectedVersionPattern -and $versionText -notmatch $ExpectedVersionPattern) {
    throw "OpenSSH version output did not match '$ExpectedVersionPattern': $versionText"
}

$algorithmResults = [ordered]@{}
foreach ($algorithmClass in @('kex', 'cipher', 'mac', 'key')) {
    $caseItems = @(Invoke-RawProcess -Name ('algorithms-' + $algorithmClass) -FileName $SshPath -Arguments @('-Q', $algorithmClass) -OutputDirectory $runRoot)
    $case = $caseItems[-1]
    if ($case.exitCode -ne 0 -or $case.standardOutputBytes -eq 0 -or $case.standardErrorBytes -ne 0) {
        throw "OpenSSH algorithm inventory failed: $algorithmClass"
    }
    $algorithmPath = Join-Path $runRoot ('algorithms-' + $algorithmClass + '\stdout.bin')
    $algorithmText = $utf8.GetString([IO.File]::ReadAllBytes($algorithmPath))
    $algorithmResults[$algorithmClass] = @($algorithmText -split "`r?`n" | Where-Object { $_ })
}

$effectiveArguments = @(
    '-G', '-F', 'NUL',
    '-o', 'BatchMode=yes',
    '-o', 'CanonicalizeHostname=no',
    '-o', 'CheckHostIP=no',
    '-o', 'GlobalKnownHostsFile=NUL',
    '-o', 'UserKnownHostsFile=NUL',
    '-p', '22',
    's00.invalid'
)
$effectiveItems = @(Invoke-RawProcess -Name 'effective-config' -FileName $SshPath -Arguments $effectiveArguments -OutputDirectory $runRoot)
$effective = $effectiveItems[-1]
if ($effective.exitCode -ne 0 -or $effective.standardOutputBytes -eq 0) {
    throw 'OpenSSH isolated effective-configuration query failed.'
}

$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$acceptedClient = $null
try {
    $listener.Start()
    $listenerPort = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $acceptTask = $listener.AcceptTcpClientAsync()
    $cancelArguments = @(
        '-F', 'NUL',
        '-o', 'BatchMode=yes',
        '-o', 'CanonicalizeHostname=no',
        '-o', 'CheckHostIP=no',
        '-o', 'ConnectionAttempts=1',
        '-o', 'ConnectTimeout=30',
        '-o', 'GlobalKnownHostsFile=NUL',
        '-o', 'UserKnownHostsFile=NUL',
        '-p', $listenerPort.ToString([Globalization.CultureInfo]::InvariantCulture),
        's00@127.0.0.1'
    )
    $cancelItems = @(Invoke-RawProcess -Name 'cancel-stalled-peer' -FileName $SshPath -Arguments $cancelArguments -OutputDirectory $runRoot -TimeoutSeconds 10 -CancelAfterMilliseconds 750)
    $cancel = $cancelItems[-1]
    if ($acceptTask.Wait(2000)) { $acceptedClient = $acceptTask.Result }
    if (-not $acceptedClient -or -not $cancel.cancelRequested -or $cancel.timedOut -or $cancel.elapsedMilliseconds -ge 5000) {
        throw 'OpenSSH stalled-peer cancellation did not complete within the bounded contract.'
    }
}
finally {
    if ($acceptedClient) { $acceptedClient.Dispose() }
    $listener.Stop()
}

$manifest = [ordered]@{
    schema = 'vt7-openssh-s00-preflight-v1'
    capturedUtc = [DateTime]::UtcNow.ToString('o')
    complete = $true
    scope = 'Endpoint-independent OpenSSH identity, raw-channel, isolated-configuration, algorithm and cancellation preflight'
    environment = [ordered]@{
        osVersion = [Environment]::OSVersion.VersionString
        is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
        is64BitProcess = [Environment]::Is64BitProcess
        culture = [Globalization.CultureInfo]::CurrentCulture.Name
        uiCulture = [Globalization.CultureInfo]::CurrentUICulture.Name
        powershell = $PSVersionTable.PSVersion.ToString()
    }
    client = [ordered]@{
        path = $SshPath
        bytes = (Get-Item -LiteralPath $SshPath).Length
        sha256 = $sshHash
        fileVersion = $clientVersion.FileVersion
        productVersion = $clientVersion.ProductVersion
        versionOutput = $versionText
        signatureStatus = $signatureStatus
        signerSubject = $signerSubject
    }
    channelAssertions = [ordered]@{
        versionUsesStandardErrorOnly = $true
        algorithmsUseStandardOutputOnly = $true
        effectiveConfigUsesRedirectedOutput = $true
        stdoutAndStderrCapturedAsRawBytes = $true
    }
    algorithms = $algorithmResults
    cancellation = [ordered]@{
        acceptedLoopbackConnection = $true
        cancelRequested = $cancel.cancelRequested
        timedOut = $cancel.timedOut
        elapsedMilliseconds = $cancel.elapsedMilliseconds
        exitCode = $cancel.exitCode
    }
    remaining = @(
        'Known and unknown host trust behavior against a real SSH server',
        'Exact remote UTF-8 and VT byte fixture without a PTY',
        'Initial remote PTY dimensions',
        'Live SSH window-change control after resize',
        'Interactive authentication and passphrase prompt ownership',
        'Drain and exit ordering during remote output'
    )
}
[IO.File]::WriteAllText((Join-Path $runRoot 'manifest.json'), ($manifest | ConvertTo-Json -Depth 12), $utf8)

Write-Host "S00 endpoint-independent preflight passed: $runRoot"
[pscustomobject]@{
    Run = $runRoot
    SshVersion = $versionText
    SshSHA256 = $sshHash
    CancelMilliseconds = $cancel.elapsedMilliseconds
    RemainingNetworkCases = $manifest.remaining.Count
}
