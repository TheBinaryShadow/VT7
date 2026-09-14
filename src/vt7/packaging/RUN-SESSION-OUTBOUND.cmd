@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7SessionOutbound.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%~dp0Logs"
set "VT7_EXIT=%ERRORLEVEL%"
if not "%VT7_EXIT%"=="0" echo Session outbound validation failed with exit code %VT7_EXIT%.
if not defined VT7_TEST_NO_PAUSE pause
exit /b %VT7_EXIT%
