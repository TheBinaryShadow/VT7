@echo off
setlocal
cd /d "%~dp0"
start "VT7 Windows PowerShell 5.1" "%~dp0VT7.Host.exe" --profile windows-powershell
