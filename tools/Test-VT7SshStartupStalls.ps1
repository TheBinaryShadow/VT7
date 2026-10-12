[CmdletBinding()]
param([string]$BinaryDirectory, [string]$OutputDirectory, [string]$FixtureFile, [switch]$SelfTest, [switch]$VerifyOnly)
# Runs on Windows 7's original PowerShell 2.0 as well as 5.1.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BinaryDirectory) { $BinaryDirectory = $scriptDirectory }
$binaryRoot = [IO.Path]::GetFullPath($BinaryDirectory)
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $binaryRoot 'Logs' }
$runRoot = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ('ssh-lifecycle-sl01-3-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($runRoot) | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$stage = 'package verification'
$secret = $null
$process = $null
function Hash-File([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Clear(); $stream.Dispose() }
}
function Quote-Argument([string]$Value) {
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}
try {
    $seen = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $binaryRoot 'SHA256SUMS.txt'))) {
        if ($line -notmatch '^([a-f0-9]{64})  ([A-Za-z0-9_. /-]+)$') { throw 'Invalid inventory.' }
        $hash = $matches[1]; $name = $matches[2]
        if ($seen.ContainsKey($name) -or $name.Split('/') -contains '..' -or $name.StartsWith('/')) { throw 'Unsafe inventory.' }
        $path = [IO.Path]::GetFullPath((Join-Path $binaryRoot $name.Replace('/', '\')))
        if (-not $path.StartsWith($binaryRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
            (Hash-File $path) -ne $hash) { throw 'Package hash mismatch.' }
        $seen[$name] = $true
    }
    foreach ($required in @('VT7.Host.exe', 'VT7.Native.dll', 'Renci.SshNet.dll', 'shim/ssh.exe', 'kh01-5-selftest.fixture',
        'RUN-SSH-LIFECYCLE-SL01-3.cmd', 'Test-VT7SshStartupStalls.ps1', 'server/VT7-SL01-3-server.py', 'PACKAGE-MANIFEST.json')) {
        if (-not $seen.ContainsKey($required)) { throw 'Incomplete package.' }
    }
    $hostPath = Join-Path $binaryRoot 'VT7.Host.exe'
    if ([Diagnostics.FileVersionInfo]::GetVersionInfo($hostPath).FileVersion -ne '0.16.0.0') { throw 'Unexpected host version.' }
    $release = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release
    if ($release -lt 528040) { throw '.NET Framework 4.8 is required.' }
    [IO.File]::WriteAllLines((Join-Path $runRoot 'RUN-ENVIRONMENT.txt'), [string[]]@(
        'Schema=vt7-sl01-3-run-v1', ('Computer=' + $env:COMPUTERNAME),
        ('OS=' + [Environment]::OSVersion.Version), ('PowerShell=' + $PSVersionTable.PSVersion),
        ('FrameworkRelease=' + $release), 'ApplicationVersion=0.16.0',
        ('HostSHA256=' + (Hash-File $hostPath)), ('NativeSHA256=' + (Hash-File (Join-Path $binaryRoot 'VT7.Native.dll'))),
        ('SshNetSHA256=' + (Hash-File (Join-Path $binaryRoot 'Renci.SshNet.dll'))),
        ('ManifestSHA256=' + (Hash-File (Join-Path $binaryRoot 'PACKAGE-MANIFEST.json'))),
        ('VerifiedFiles=' + $seen.Count), ('SelfTest=' + [bool]$SelfTest), ('VerifyOnly=' + [bool]$VerifyOnly)), $utf8)
    if (-not $VerifyOnly) {
        $modes = @('ssh-lifecycle-test', 'window-smoke-test', 'winpty-session-test', 'session-stream-test',
            'session-outbound-test', 'sshnet-foundation-test', 'ssh-overlay-no-external-test', 'known-hosts-certificate-self-test')
        if (-not $SelfTest) { $modes += 'ssh-startup-stall-test' }
        foreach ($mode in $modes) {
            $stage = $mode
            $reportPath = Join-Path $runRoot ($mode + '.log')
            $start = New-Object Diagnostics.ProcessStartInfo
            $start.FileName = $hostPath
            $start.WorkingDirectory = $binaryRoot
            $start.UseShellExecute = $false
            $start.CreateNoWindow = $true
            $start.Arguments = '--' + $mode + ' --diagnostics-output ' + (Quote-Argument $reportPath)
            if ($mode -eq 'known-hosts-certificate-self-test') {
                $start.Arguments += ' --certificate-fixture ' + (Quote-Argument (Join-Path $binaryRoot 'kh01-5-selftest.fixture'))
            }
            Write-Output ('Running ' + $mode + '...')
            if ($mode -eq 'ssh-startup-stall-test') {
                if (-not $FixtureFile) { $FixtureFile = Read-Host 'Full path to public SL01.3 client.fixture copied from Debian' }
                $fixturePath = [IO.Path]::GetFullPath($FixtureFile)
                if (-not [IO.File]::Exists($fixturePath) -or (Get-Item -LiteralPath $fixturePath).Length -gt 16384) { throw 'Invalid fixture path.' }
                $keyPath = Read-Host 'Full path to the dedicated private key matching the public key used for prepare'
                $keyPath = [IO.Path]::GetFullPath($keyPath)
                if (-not [IO.File]::Exists($keyPath)) { throw 'Private key does not exist.' }
                $secret = Read-Host 'Private-key passphrase (Enter if unencrypted)' -AsSecureString
                $start.RedirectStandardInput = $true
                $start.Arguments += ' --startup-fixture ' + (Quote-Argument $fixturePath)
                [IO.File]::AppendAllText((Join-Path $runRoot 'RUN-ENVIRONMENT.txt'), ('FixtureSHA256=' + (Hash-File $fixturePath) + "`n"), $utf8)
            }
            $process = [Diagnostics.Process]::Start($start)
            if ($mode -eq 'ssh-startup-stall-test') {
                # Private path/passphrase go only through the owned anonymous stdin pipe.
                $writer = New-Object IO.StreamWriter($process.StandardInput.BaseStream, $utf8)
                $bstr = [IntPtr]::Zero
                try {
                    $writer.Write($keyPath + "`n")
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
            if (-not $process.WaitForExit(240000)) { $process.Kill(); throw 'Diagnostic watchdog expired.' }
            if ($process.ExitCode -ne 0 -or -not [IO.File]::Exists($reportPath)) { throw 'Diagnostic failed.' }
            $text = [IO.File]::ReadAllText($reportPath, $utf8)
            if ($text -notmatch '(?m)^Passed: True\r?$' -or $text -notmatch 'Native: ABI 11, expected 11' -or
                $text.Contains('SL01_PRIVATE_SENTINEL')) { throw 'Invalid diagnostic result or secret disclosure.' }
            if ($mode -eq 'ssh-lifecycle-test' -and ($text -notmatch 'PASS: SL01.1 typed command-prompt' -or
                $text -notmatch 'PASS: SL01.1 stalled KEX' -or $text -notmatch 'PASS: SL01.1 closing a window' -or
                $text -notmatch 'PASS: SL01.2 pinned-library identification' -or
                $text -notmatch 'PASS: SL01.2 pinned-library key-exchange' -or
                $text -notmatch 'PASS: SL01.2 late resolver deadline' -or
                $text -notmatch 'PASS: SL01.2 late resolver cancellation' -or
                $text -notmatch 'PASS: SL01.2 typed command-prompt startup timeout' -or
                $text -notmatch 'PASS: SL01.2 deadline policy' -or
                $text -notmatch 'PASS: SL01.2 late synchronous known-host')) {
                throw 'Incomplete lifecycle matrix.'
            }
            if ($mode -eq 'ssh-startup-stall-test') {
                foreach ($case in @('ready-before', 'auth-timeout', 'auth-late', 'auth-cancel', 'auth-close',
                    'pty-timeout', 'pty-late', 'pty-cancel', 'pty-close', 'typed-auth-timeout', 'typed-pty-timeout', 'ready-after')) {
                    if (-not $text.Contains('PASS: SL01.3 ' + $case + ' ')) { throw 'Incomplete startup stall matrix.' }
                }
                if ($text -notmatch '(?m)^Cases=12\r?$' -or $text -notmatch '(?m)^(?:Surface: )?FixtureId=[a-f0-9]{32}\r?$' -or
                    $text -notmatch '(?m)^RunId=[a-f0-9]{32}\r?$') { throw 'Missing paired-audit identity.' }
            }
            $process.Dispose(); $process = $null
            Write-Output ('PASS: ' + $mode)
        }
    }
    [IO.File]::WriteAllLines((Join-Path $runRoot 'RESULT.txt'), [string[]]@('PackageVerified=True',
        ('ClientPassed=' + (-not [bool]$VerifyOnly)), 'LiveAccepted=False', 'ServerAuditAccepted=False'), $utf8)
    Write-Output ('PASS: SL01.3 client. Pair the server audit for a live run. Return this complete log folder, including on a passing run: ' + $runRoot)
}
catch {
    [IO.File]::WriteAllLines((Join-Path $runRoot 'RESULT.txt'), [string[]]@('ClientPassed=False', ('FailureStage=' + $stage)), $utf8)
    [Console]::Error.WriteLine('SL01.3 failed at ' + $stage + '. Evidence retained: ' + $runRoot)
    exit 1
}
finally {
    if ($secret) { $secret.Dispose() }
    if ($process) {
        if (-not $process.HasExited) { $process.Kill() }
        $process.Dispose()
    }
}
