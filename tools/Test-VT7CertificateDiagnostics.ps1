[CmdletBinding()]
param([string]$BinaryDirectory = (Join-Path $PSScriptRoot '..\artifacts\vt7\bin\Release'),
    [switch]$FailureControlOnly)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binaryRoot = [IO.Path]::GetFullPath($BinaryDirectory)
$reportRoot = Join-Path $repositoryRoot ('artifacts\vt7\diagnostics\kh01-5-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($reportRoot) | Out-Null
$fixture = Join-Path $repositoryRoot 'src\vt7\packaging\kh01-5-selftest.fixture'
$modes = @('known-hosts-certificate-self-test', 'sshnet-foundation-test', 'ssh-overlay-no-external-test', 'h01-test')
if ($FailureControlOnly) { $modes = @() }
foreach ($mode in $modes) {
    $report = Join-Path $reportRoot ($mode + '.log')
    $arguments = '--' + $mode + ' --diagnostics-output "' + $report + '"'
    if ($mode -eq 'known-hosts-certificate-self-test') { $arguments += ' --certificate-fixture "' + $fixture + '"' }
    if ($mode -eq 'h01-test') { $arguments += ' --allow-missing-powershell-7' }
    $process = Start-Process -FilePath (Join-Path $binaryRoot 'VT7.Host.exe') -ArgumentList $arguments -PassThru -WindowStyle Hidden
    try {
        if (-not $process.WaitForExit(90000)) { $process.Kill(); throw 'Diagnostic timed out.' }
        if ($process.ExitCode -ne 0 -or [IO.File]::ReadAllText($report) -notmatch 'Passed: True') { throw "Diagnostic failed: $mode" }
    }
    finally { $process.Dispose() }
    Write-Output ('PASS: ' + $mode)
}
# A closed loopback port must fail, rather than produce a false policy-rejection
# pass. Also exercise redirected UTF-8 stdin on the real WPF diagnostic host.
$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$listener.Start(); $closedPort = $listener.LocalEndpoint.Port; $listener.Stop()
$liveFixture = Join-Path $reportRoot 'closed-port.fixture'
$fixtureText = [IO.File]::ReadAllText($fixture) -replace 'basePort=22350', ('basePort=' + $closedPort)
if ($closedPort -gt 65527) { throw 'Ephemeral port range is unsuitable; rerun the diagnostic.' }
[IO.File]::WriteAllText($liveFixture, $fixtureText, (New-Object Text.UTF8Encoding($false)))
$report = Join-Path $reportRoot 'closed-port-rejection.log'
$keyPath = Join-Path $reportRoot 'disposable-test-key'
$keyStart = New-Object Diagnostics.ProcessStartInfo
$keyStart.FileName = (Get-Command ssh-keygen.exe -ErrorAction Stop).Source
$keyStart.UseShellExecute = $false; $keyStart.CreateNoWindow = $true
$keyStart.Arguments = '-q -t ed25519 -N "" -f "' + $keyPath + '"'
$keyProcess = [Diagnostics.Process]::Start($keyStart)
try { $keyProcess.WaitForExit(); if ($keyProcess.ExitCode -ne 0) { throw 'Disposable key creation failed.' } }
finally { $keyProcess.Dispose() }
$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = Join-Path $binaryRoot 'VT7.Host.exe'
$start.UseShellExecute = $false; $start.CreateNoWindow = $true; $start.RedirectStandardInput = $true
$start.Arguments = '--known-hosts-certificate-test --certificate-fixture "' + $liveFixture + '" --diagnostics-output "' + $report + '"'
$process = [Diagnostics.Process]::Start($start)
try {
    $writer = New-Object IO.StreamWriter($process.StandardInput.BaseStream, (New-Object Text.UTF8Encoding($false)))
    $sentinel = 'VT7_PRIVATE_SENTINEL_' + [Guid]::NewGuid().ToString('N') + [char]0x0107
    $writer.Write('127.0.0.1' + "`n" + 'private_diagnostic_user' + "`n" + $keyPath + "`n" + $sentinel + "`n")
    $writer.Dispose()
    if (-not $process.WaitForExit(35000)) { $process.Kill(); throw 'Credential-pipe failure control timed out.' }
    $text = [IO.File]::ReadAllText($report)
    if ($process.ExitCode -ne 1 -or $text -notmatch 'KH01.5 failed at direct valid' -or
        $text.Contains($sentinel) -or $text.Contains('private_diagnostic_user') -or $text.Contains($keyPath) -or
        $text.Contains('PASS: live direct')) { throw 'Credential-pipe/fail-closed control did not behave safely.' }
}
finally {
    if (-not $process.HasExited) { $process.Kill() }; $process.Dispose()
    Remove-Item -LiteralPath $keyPath -Force
    Remove-Item -LiteralPath ($keyPath + '.pub') -Force
}
Write-Output ('PASS: anonymous UTF-8 credential pipe and failed pre-certificate connection cannot produce a passing live matrix. Evidence: ' + $reportRoot)
