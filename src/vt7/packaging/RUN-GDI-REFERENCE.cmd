@echo off
setlocal
cd /d "%~dp0"
start "VT7 GDI reference" "VT7.Host.exe" --renderer gdi
