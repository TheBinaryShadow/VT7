[CmdletBinding()]
param([string]$OutputFile = (Join-Path $PSScriptRoot '..\src\vt7\packaging\kh01-5-selftest.fixture'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$keygen = (Get-Command ssh-keygen.exe -ErrorAction Stop).Source
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('vt7-certificate-public-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporary) | Out-Null
function Invoke-Keygen([string[]]$Arguments) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $keygen
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.Arguments = ($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $process = [Diagnostics.Process]::Start($start)
    try { $process.WaitForExit(); if ($process.ExitCode -ne 0) { throw 'ssh-keygen failed.' } }
    finally { $process.Dispose() }
}
function Public-Key([string]$Path) { ([IO.File]::ReadAllText($Path).Trim() -split ' ')[0..1] -join ' ' }
try {
    foreach ($name in @('ca', 'other-ca', 'host')) {
        Invoke-Keygen @('-q', '-t', 'ed25519', '-N', '', '-f', (Join-Path $temporary $name))
    }
    # Public session-signature vectors exercise the actual pinned verification
    # gate. Only the public data/signature leave this disposable directory.
    $assemblyRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\artifacts\vt7\bin\Release'))
    Add-Type -Path (Join-Path $assemblyRoot 'BouncyCastle.Cryptography.dll')
    Add-Type -Path (Join-Path $assemblyRoot 'Renci.SshNet.dll')
    $data = [Text.Encoding]::UTF8.GetBytes('VT7 KH01.5 public certificate session-signature vector')
    $privateKey = New-Object Renci.SshNet.PrivateKeyFile((Join-Path $temporary 'host'))
    try { $signature = $privateKey.HostKeyAlgorithms[0].Sign($data) }
    finally { $privateKey.Dispose() }
    $lines = @('schema=vt7-kh01-5-fixture-v1', ('id=' + [Guid]::NewGuid().ToString('N')),
        'principal=127.0.0.1', 'basePort=22350', ('ca=' + (Public-Key (Join-Path $temporary 'ca.pub'))),
        ('hostKey=' + (Public-Key (Join-Path $temporary 'host.pub'))))
    $lines += 'selfTestData=' + [Convert]::ToBase64String($data)
    $lines += 'selfTestSignature=' + [Convert]::ToBase64String($signature)
    foreach ($name in @('valid', 'wrong-principal', 'expired', 'not-yet-valid', 'critical-option', 'untrusted-ca')) {
        $public = Join-Path $temporary ($name + '.pub')
        Copy-Item -LiteralPath (Join-Path $temporary 'host.pub') -Destination $public
        $authority = 'ca'; $principal = '127.0.0.1'; $validity = '20200101000000:20990101000000'
        if ($name -eq 'wrong-principal') { $principal = '192.0.2.123' }
        if ($name -eq 'expired') { $validity = '20000101000000:20010101000000' }
        if ($name -eq 'not-yet-valid') { $validity = '21000101000000:21010101000000' }
        if ($name -eq 'untrusted-ca') { $authority = 'other-ca' }
        $arguments = @('-q', '-s', (Join-Path $temporary $authority), '-I', ('vt7-selftest-' + $name), '-h', '-n', $principal, '-V', $validity)
        if ($name -eq 'critical-option') { $arguments += @('-O', 'critical:vt7-test=deny') }
        Invoke-Keygen ($arguments + $public)
        $lines += 'cert.' + $name + '=' + (Public-Key (Join-Path $temporary ($name + '-cert.pub')))
    }
    [IO.File]::WriteAllLines([IO.Path]::GetFullPath($OutputFile), $lines, (New-Object Text.UTF8Encoding($false)))
    Write-Output 'Wrote public signed-certificate self-test corpus; private fixture keys discarded.'
}
finally {
    # Only delete the freshly generated GUID directory, never the caller's output.
    if ([IO.Path]::GetFileName($temporary) -match '^vt7-certificate-public-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
}
