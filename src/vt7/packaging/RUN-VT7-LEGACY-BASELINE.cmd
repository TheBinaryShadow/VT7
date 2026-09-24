@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "VT7_OUTPUT=%~dp0Logs"
if defined VT7_TEST_OUTPUT_DIRECTORY set "VT7_OUTPUT=%VT7_TEST_OUTPUT_DIRECTORY%"
if not exist "%VT7_OUTPUT%" mkdir "%VT7_OUTPUT%"
if not exist "%VT7_OUTPUT%" goto failed

echo VT7 legacy baseline prerequisite check > "%VT7_OUTPUT%\prerequisites.txt"
ver >> "%VT7_OUTPUT%\prerequisites.txt"
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release >> "%VT7_OUTPUT%\prerequisites.txt" 2>&1
if errorlevel 1 goto missing_net
set "VT7_NET_RELEASE="
for /f "skip=1 tokens=3" %%R in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2^>nul') do set /a VT7_NET_RELEASE=%%R
if not defined VT7_NET_RELEASE goto missing_net
if %VT7_NET_RELEASE% LSS 528040 goto missing_net

echo Windows PowerShell engine version: >> "%VT7_OUTPUT%\prerequisites.txt"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$PSVersionTable.PSVersion.ToString()" >> "%VT7_OUTPUT%\prerequisites.txt" 2>&1
if errorlevel 1 goto failed
if not exist "%~dp0VT7.Host.exe" goto failed

echo Running window smoke check...
start "" /wait "%~dp0VT7.Host.exe" --window-smoke-test --renderer atlas-auto --diagnostics-output "%VT7_OUTPUT%\window-smoke.log"
if errorlevel 1 goto failed
echo Running Command Prompt transport check...
start "" /wait "%~dp0VT7.Host.exe" --winpty-session-test --renderer atlas-auto --diagnostics-output "%VT7_OUTPUT%\winpty-session.log"
if errorlevel 1 goto failed
echo Running session stream check...
start "" /wait "%~dp0VT7.Host.exe" --session-stream-test --renderer atlas-auto --diagnostics-output "%VT7_OUTPUT%\session-stream.log"
if errorlevel 1 goto failed
echo Running session outbound check...
start "" /wait "%~dp0VT7.Host.exe" --session-outbound-test --renderer atlas-auto --diagnostics-output "%VT7_OUTPUT%\session-outbound.log"
if errorlevel 1 goto failed
echo Running SSH.NET foundation check...
start "" /wait "%~dp0VT7.Host.exe" --sshnet-foundation-test --renderer atlas-auto --diagnostics-output "%VT7_OUTPUT%\sshnet-foundation.log"
if errorlevel 1 goto failed
echo Running typed SSH without OpenSSH check...
start "" /wait "%~dp0VT7.Host.exe" --ssh-overlay-no-external-test --renderer atlas-auto --diagnostics-output "%VT7_OUTPUT%\ssh-overlay-no-external.log"
if errorlevel 1 goto failed
echo PASS: VT7 legacy baseline. Logs: "%VT7_OUTPUT%"
if not defined VT7_TEST_NO_PAUSE pause
exit /b 0

:missing_net
echo FAIL: VT7 requires .NET Framework 4.8. See "%VT7_OUTPUT%\prerequisites.txt".
if not defined VT7_TEST_NO_PAUSE pause
exit /b 2

:failed
echo FAIL: VT7 legacy baseline. Return the complete "%VT7_OUTPUT%" directory.
if not defined VT7_TEST_NO_PAUSE pause
exit /b 1
