@echo off
setlocal
cd /d "%~dp0"
if not exist Logs mkdir Logs
set "VT7_RESULT=0"
VT7.AtlasProof.exe --self-test --output "Logs\Direct3D11-hardware.log" --capture "Logs\Direct3D11-hardware.png"
if errorlevel 1 set "VT7_RESULT=1"
VT7.AtlasProof.exe --self-test --warp --output "Logs\Direct3D11-WARP.log" --capture "Logs\Direct3D11-WARP.png"
if errorlevel 1 set "VT7_RESULT=1"
VT7.AtlasProof.exe --self-test --d2d --output "Logs\Direct2D-hardware.log" --capture "Logs\Direct2D-hardware.png"
if errorlevel 1 set "VT7_RESULT=1"
VT7.AtlasProof.exe --self-test --d2d --warp --output "Logs\Direct2D-WARP.log" --capture "Logs\Direct2D-WARP.png"
if errorlevel 1 set "VT7_RESULT=1"
echo.
echo Atlas backend tests finished. Exit code: %VT7_RESULT% (0 means pass).
echo Please send the Logs folder, including any failed reports.
pause
exit /b %VT7_RESULT%
