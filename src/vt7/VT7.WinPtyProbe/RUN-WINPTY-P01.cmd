@echo off
setlocal
if not exist "%~dp0Logs" mkdir "%~dp0Logs"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7WinPty.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputRoot "%~dp0Logs"
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" echo P01 failed with exit code %EXITCODE%.
if not "%VT7_P01_NO_PAUSE%"=="1" pause
exit /b %EXITCODE%
