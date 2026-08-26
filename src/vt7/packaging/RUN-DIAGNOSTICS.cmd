@echo off
setlocal
cd /d "%~dp0"
VT7.Host.exe --diagnostics --diagnostics-output "%~dp0VT7-diagnostics.log"
set "vt7_exit=%ERRORLEVEL%"
if "%vt7_exit%"=="0" (
    echo VT7 diagnostics passed.
) else (
    echo VT7 diagnostics failed with exit code %vt7_exit%.
)
echo Report: %~dp0VT7-diagnostics.log
pause
exit /b %vt7_exit%
