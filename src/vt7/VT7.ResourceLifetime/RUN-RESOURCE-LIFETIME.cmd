@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-ResourceLifetime.ps1"
set "vt7_exit=%errorlevel%"
echo.
if "%vt7_exit%"=="0" (echo Both measurements completed. Growth is not accepted by this launcher.) else echo Comparison incomplete. Keep all partial logs.
if /i not "%~1"=="--no-pause" pause
exit /b %vt7_exit%
