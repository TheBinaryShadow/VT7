@echo off
setlocal
cd /d "%~dp0"
start "VT7 Atlas WARP" "VT7.Host.exe" --renderer atlas-d3d-warp
