[CmdletBinding()]
param([string]$BinaryDirectory, [string]$OutputDirectory, [string]$FixtureFile,
    [switch]$SelfTest, [switch]$VerifyOnly)
# Target runner intentionally supports the original Windows 7 PowerShell 2.0.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BinaryDirectory) { $BinaryDirectory = $scriptDirectory }
$binaryRoot = [IO.Path]::GetFullPath($BinaryDirectory)
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $binaryRoot 'Logs' }
$runRoot = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ('known-hosts-kh01-5-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($runRoot) | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
function Hash-File([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Clear(); $stream.Dispose() }
}
function Quote-Argument([string]$Value) {
    # Windows CommandLineToArgvW quoting; this text is never passed to a shell.
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}
$stage = 'package verification'
$process = $null
$secret = $null
try {
    $count = 0
    $seen = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $binaryRoot 'SHA256SUMS.txt'))) {
        if ($line -notmatch '^([a-f0-9]{64})  ([A-Za-z0-9_. /-]+)$') { throw 'Invalid inventory.' }
        $hash = $matches[1]; $name = $matches[2]
        if ($seen.ContainsKey($name) -or $name.Split('/') -contains '..' -or $name.StartsWith('/')) { throw 'Unsafe inventory.' }
        $path = [IO.Path]::GetFullPath((Join-Path $binaryRoot $name.Replace('/', '\')))
        if (-not $path.StartsWith($binaryRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
            (Hash-File $path) -ne $hash) { throw 'Package file hash differs from the inventory.' }
        $seen[$name] = $true; ++$count
    }
    foreach ($required in @('VT7.Host.exe', 'VT7.Native.dll', 'Renci.SshNet.dll', 'shim/ssh.exe', 'kh01-5-selftest.fixture',
        'RUN-KNOWN-HOSTS-KH01-5.cmd', 'Test-VT7KnownHostsCertificates.ps1', 'server/VT7-KH01-5-server.sh', 'server/VT7-KH01-5-audit.py')) {
        if (-not $seen.ContainsKey($required)) { throw 'Package inventory is incomplete.' }
    }
    $hostPath = Join-Path $binaryRoot 'VT7.Host.exe'
    if ([Diagnostics.FileVersionInfo]::GetVersionInfo($hostPath).FileVersion -ne '0.13.1.0') { throw 'Unexpected application version.' }
    $release = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release
    if ($release -lt 528040) { throw '.NET Framework 4.8 or later is required.' }
    $environmentLines = @('Schema=vt7-kh01-5-run-v1', ('Computer=' + $env:COMPUTERNAME),
        ('OS=' + [Environment]::OSVersion.Version.ToString()), ('PowerShell=' + $PSVersionTable.PSVersion.ToString()),
        ('FrameworkRelease=' + $release), 'ApplicationVersion=0.13.1',
        ('HostSHA256=' + (Hash-File $hostPath)), ('NativeSHA256=' + (Hash-File (Join-Path $binaryRoot 'VT7.Native.dll'))),
        ('SshNetSHA256=' + (Hash-File (Join-Path $binaryRoot 'Renci.SshNet.dll'))), ('VerifiedFiles=' + $count),
        ('SelfTest=' + [bool]$SelfTest), ('VerifyOnly=' + [bool]$VerifyOnly))
    [IO.File]::WriteAllLines((Join-Path $runRoot 'RUN-ENVIRONMENT.txt'), [string[]]$environmentLines, $utf8)
    if ($VerifyOnly) {
        [IO.File]::WriteAllText((Join-Path $runRoot 'RESULT.txt'), "PackageVerified=True`nLiveAccepted=False`n", $utf8)
        Write-Output ('PASS: package hashes and prerequisites. Evidence: ' + $runRoot)
        exit 0
    }
    $stage = 'fixture and credential input'
    if ($SelfTest) { $FixtureFile = Join-Path $binaryRoot 'kh01-5-selftest.fixture' }
    elseif (-not $FixtureFile) { $FixtureFile = Read-Host 'Full path to the public client.fixture copied from your Debian fixture' }
    $fixturePath = [IO.Path]::GetFullPath($FixtureFile)
    $fixtureLines = [IO.File]::ReadAllLines($fixturePath, $utf8)
    $identity = ''; $principal = ''
    foreach ($line in $fixtureLines) {
        if ($line -match '^id=([a-f0-9]{32})$') { $identity = $matches[1] }
        if ($line -match '^principal=([0-9.]+)$') { $principal = $matches[1] }
    }
    if (-not $identity -or -not $principal) { throw 'Invalid public fixture.' }
    if (-not $SelfTest) {
        Write-Output 'Use only the dedicated Debian fixture, with fresh server logs for this one run.'
        Write-Output ('Fixture IPv4 address: ' + $principal)
        $user = Read-Host 'SSH test username [sshtest]'
        if (-not $user) { $user = 'sshtest' }
        if ($user -notmatch '^[A-Za-z0-9_.-]{1,64}$') { throw 'Invalid test username.' }
        $keyPath = Read-Host 'Full path to the dedicated private key [USERPROFILE\.ssh\id_rsa]'
        if (-not $keyPath) { $keyPath = Join-Path $env:USERPROFILE '.ssh\id_rsa' }
        $keyPath = [IO.Path]::GetFullPath($keyPath)
        if (-not [IO.File]::Exists($keyPath)) { throw 'Private key does not exist.' }
        $secret = Read-Host 'Private-key passphrase (Enter if unencrypted)' -AsSecureString
    }
    $reportPath = Join-Path $runRoot 'known-hosts-certificates.log'
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $hostPath
    $start.WorkingDirectory = $binaryRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = -not $SelfTest
    $mode = '--known-hosts-certificate-test'
    if ($SelfTest) { $mode = '--known-hosts-certificate-self-test' }
    $start.Arguments = $mode + ' --certificate-fixture ' + (Quote-Argument $fixturePath) + ' --diagnostics-output ' + (Quote-Argument $reportPath)
    $stage = 'client certificate matrix'
    $process = [Diagnostics.Process]::Start($start)
    if (-not $SelfTest) {
        # Credentials exist only in the parent's memory and its anonymous stdin
        # pipe. Do not use command arguments, environment variables or temp files.
        $writer = New-Object IO.StreamWriter($process.StandardInput.BaseStream, $utf8)
        $bstr = [IntPtr]::Zero
        try {
            $writer.Write($principal + "`n" + $user + "`n" + $keyPath + "`n")
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
            for ($index = 0; $index -lt $secret.Length; ++$index) {
                $writer.Write([char]([Runtime.InteropServices.Marshal]::ReadInt16($bstr, 2 * $index) -band 65535))
            }
            $writer.Write("`n"); $writer.Flush()
        }
        finally {
            if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
            $writer.Dispose(); $secret.Dispose(); $secret = $null
        }
    }
    if (-not $process.WaitForExit(300000)) { $process.Kill(); throw 'Client matrix timed out.' }
    if ($process.ExitCode -ne 0 -or -not [IO.File]::Exists($reportPath)) { throw 'Client matrix failed; inspect the safe diagnostic report.' }
    $text = [IO.File]::ReadAllText($reportPath, $utf8)
    if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -notmatch 'Native: ABI 11, expected 11') { throw 'Client report did not pass.' }
    if ($SelfTest) {
        if ([regex]::Matches($text, 'PASS: certificate adapter ').Count -ne 9) { throw 'Self-test matrix is incomplete.' }
    }
    else {
        if ([regex]::Matches($text, 'PASS: live direct ').Count -ne 9 -or $text -notmatch ('FixtureId=' + $identity) -or
            $text -notmatch '(?m)^AcceptedConnections=([3-5])\r?$') { throw 'Live matrix is incomplete.' }
        $accepted = $matches[1]
        Write-Output ('Client matrix passed. On Debian run: sudo bash server/VT7-KH01-5-server.sh audit FIXTURE_ROOT ' + $accepted)
    }
    [IO.File]::WriteAllText((Join-Path $runRoot 'RESULT.txt'), ('ClientPassed=True' + "`n" + 'LiveAccepted=False' + "`n"), $utf8)
    Write-Output ('PASS: KH01.5 client checks. Return this complete log folder: ' + $runRoot)
    if (-not $SelfTest) { Write-Output 'Also return the matching server-audit.txt, even when everything passes. Then reset the server before testing another machine.' }
}
catch {
    # Do not forward arbitrary process/key-path exception messages to evidence.
    [IO.File]::WriteAllText((Join-Path $runRoot 'RESULT.txt'), ('ClientPassed=False' + "`n" + 'FailureStage=' + $stage + "`n"), $utf8)
    Write-Error ('KH01.5 failed at ' + $stage + '. Evidence retained: ' + $runRoot)
    exit 1
}
finally {
    if ($secret) { $secret.Dispose() }
    if ($process) {
        if (-not $process.HasExited) { $process.Kill() }
        $process.Dispose()
    }
}
