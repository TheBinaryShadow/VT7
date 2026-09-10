@echo off
setlocal
cd /d "%~dp0"
start "" /wait "VT7.Host.exe" --window-smoke-test --diagnostics-output "%~dp0VT7-viewport-test.log"
set "vt7_exit=%ERRORLEVEL%"
if "%vt7_exit%"=="0" (
    echo VT7 viewport tests passed.
) else (
    echo VT7 viewport tests failed with exit code %vt7_exit%.
)
echo Report: %~dp0VT7-viewport-test.log
pause
exit /b %vt7_exit%
