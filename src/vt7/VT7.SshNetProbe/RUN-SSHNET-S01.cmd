@echo off
setlocal
cd /d "%~dp0"
set "VT7_ARGS="
if /i "%~1"=="--self-test" set "VT7_ARGS=-SelfTest"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-SshNetS01.ps1" %VT7_ARGS%
set "VT7_EXIT=%ERRORLEVEL%"
if not "%VT7_EXIT%"=="0" echo S01 characterization failed with exit code %VT7_EXIT%.
if not defined VT7_S01_NO_PAUSE pause
exit /b %VT7_EXIT%
