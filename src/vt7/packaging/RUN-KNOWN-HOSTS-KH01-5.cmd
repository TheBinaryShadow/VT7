@echo off
setlocal
set "VT7_MODE="
if /i "%~1"=="--self-test" set "VT7_MODE=-SelfTest"
if /i "%~1"=="--verify-only" set "VT7_MODE=-VerifyOnly"
if not "%~1"=="" if "%VT7_MODE%"=="" goto usage
if not "%~2"=="" goto usage
set "VT7_LOGS=%~dp0Logs"
if defined VT7_TEST_OUTPUT_DIRECTORY set "VT7_LOGS=%VT7_TEST_OUTPUT_DIRECTORY%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7KnownHostsCertificates.ps1" -BinaryDirectory "%~dp0." -OutputDirectory "%VT7_LOGS%" %VT7_MODE%
set "VT7_RESULT=%ERRORLEVEL%"
echo VT7 KH01.5 client validation finished with exit code %VT7_RESULT%.
if not defined VT7_TEST_NO_PAUSE pause
exit /b %VT7_RESULT%
:usage
echo Usage: RUN-KNOWN-HOSTS-KH01-5.cmd [--self-test ^| --verify-only]
if not defined VT7_TEST_NO_PAUSE pause
exit /b 2
