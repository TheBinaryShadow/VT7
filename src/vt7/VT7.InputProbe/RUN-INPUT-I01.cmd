@echo off
setlocal
set "VT7_I01_ROOT=%~dp0."
set "VT7_I01_ARGS="
if "%VT7_I01_NONINTERACTIVE%"=="1" set "VT7_I01_ARGS=-NonInteractive"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%VT7_I01_ROOT%\Test-VT7Input.ps1" -BinaryDirectory "%VT7_I01_ROOT%" %VT7_I01_ARGS%
set "VT7_I01_EXIT=%ERRORLEVEL%"
echo.
if not "%VT7_I01_EXIT%"=="0" echo I01 failed with exit code %VT7_I01_EXIT%.
if "%VT7_I01_EXIT%"=="0" echo I01 collection completed successfully.
if not "%VT7_I01_NO_PAUSE%"=="1" pause
exit /b %VT7_I01_EXIT%
