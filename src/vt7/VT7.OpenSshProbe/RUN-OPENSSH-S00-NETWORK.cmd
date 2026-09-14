@echo off
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-OpenSshS00Network.ps1"
set "VT7_EXIT=%ERRORLEVEL%"
if not "%VT7_EXIT%"=="0" echo S00 network characterization failed with exit code %VT7_EXIT%.
pause
exit /b %VT7_EXIT%
