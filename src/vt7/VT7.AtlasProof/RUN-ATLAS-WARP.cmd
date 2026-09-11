@echo off
setlocal
cd /d "%~dp0"
if not exist Logs mkdir Logs
VT7.AtlasProof.exe --warp --output "Logs\visible-Direct3D11-WARP.log"
set "VT7_RESULT=%ERRORLEVEL%"
echo Atlas WARP window closed. Exit code: %VT7_RESULT%
pause
exit /b %VT7_RESULT%
