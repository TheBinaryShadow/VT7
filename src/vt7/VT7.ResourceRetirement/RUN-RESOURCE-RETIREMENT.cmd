@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-ResourceRetirement.ps1"
set "VT7_EXIT=%ERRORLEVEL%"
if /i not "%~1"=="--no-pause" pause
exit /b %VT7_EXIT%
