@echo off
setlocal
cd /d "%~dp0"
set "vt7_exit=0"
for %%R in (gdi atlas-d3d-hardware atlas-d3d-warp atlas-d2d-hardware atlas-d2d-warp atlas-auto) do call :test %%R
echo Reports and Atlas back-buffer PNGs: %~dp0Logs
pause
exit /b %vt7_exit%

:test
start "" /wait "VT7.Host.exe" --window-smoke-test --renderer %1 --diagnostics-output "%~dp0Logs\viewport-%1.log"
if errorlevel 1 (
    set "vt7_exit=1"
    echo FAIL: %1. Keep its log and any partial output.
) else (
    echo PASS: %1
)
exit /b
