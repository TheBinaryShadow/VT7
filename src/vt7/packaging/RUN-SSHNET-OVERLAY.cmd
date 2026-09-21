@echo off
setlocal
cd /d "%~dp0"
set "VT7_OUTPUT=%~dp0Logs"
if defined VT7_TEST_OUTPUT_DIRECTORY set "VT7_OUTPUT=%VT7_TEST_OUTPUT_DIRECTORY%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7SshOverlay.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%VT7_OUTPUT%"
set "code=%errorlevel%"
if not "%code%"=="0" echo VT7 typed SSH overlay validation failed with exit code %code%.
if "%code%"=="0" echo VT7 typed SSH overlay validation passed.
if not defined VT7_TEST_NO_PAUSE pause
exit /b %code%
