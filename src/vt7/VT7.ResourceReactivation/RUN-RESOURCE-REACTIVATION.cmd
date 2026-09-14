@echo off
setlocal
cd /d "%~dp0"
set "VT7_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "VT7_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%VT7_PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-ResourceReactivation.ps1"
set "VT7_EXIT=%ERRORLEVEL%"
if /i not "%~1"=="--no-pause" pause
exit /b %VT7_EXIT%
