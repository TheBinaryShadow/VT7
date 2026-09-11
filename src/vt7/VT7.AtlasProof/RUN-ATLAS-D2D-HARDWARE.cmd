@echo off
setlocal
cd /d "%~dp0"
if not exist Logs mkdir Logs
VT7.AtlasProof.exe --d2d --output "Logs\visible-Direct2D-hardware.log"
set "VT7_RESULT=%ERRORLEVEL%"
echo Atlas Direct2D hardware window closed. Exit code: %VT7_RESULT%
pause
exit /b %VT7_RESULT%
