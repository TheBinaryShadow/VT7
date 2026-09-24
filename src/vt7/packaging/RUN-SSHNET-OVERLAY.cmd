@echo off
setlocal
cd /d "%~dp0"
set "VT7_OUTPUT=%~dp0Logs"
if defined VT7_TEST_OUTPUT_DIRECTORY set "VT7_OUTPUT=%VT7_TEST_OUTPUT_DIRECTORY%"
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "if ($PSVersionTable.PSVersion -lt [version]'5.1') { exit 2 }"
if errorlevel 1 goto unsupported_ps
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7SshOverlay.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%VT7_OUTPUT%"
set "code=%errorlevel%"
if not "%code%"=="0" echo VT7 typed SSH overlay validation failed with exit code %code%.
if "%code%"=="0" echo VT7 typed SSH overlay validation passed.
if not defined VT7_TEST_NO_PAUSE pause
exit /b %code%

:unsupported_ps
echo VT7 typed SSH overlay test requires Windows PowerShell 5.1 or newer.
echo On PowerShell 2.0, run RUN-VT7-LEGACY-BASELINE.cmd instead.
if not defined VT7_TEST_NO_PAUSE pause
exit /b 2
