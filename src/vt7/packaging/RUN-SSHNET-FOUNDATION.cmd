@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7SshNetFoundation.ps1" -Configuration Release -BinaryDirectory "%~dp0" -OutputDirectory "%~dp0Logs"
set "code=%errorlevel%"
if not "%code%"=="0" echo VT7 SSH.NET foundation validation failed with exit code %code%.
if "%code%"=="0" echo VT7 SSH.NET foundation validation passed.
pause
exit /b %code%
