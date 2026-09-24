@echo off
setlocal
cd /d "%~dp0"
start "VT7 Windows PowerShell" "%~dp0VT7.Host.exe" --profile windows-powershell
