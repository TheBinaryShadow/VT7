@echo off
setlocal
cd /d "%~dp0"
start "VT7 PowerShell 7" "%~dp0VT7.Host.exe" --profile powershell-7
