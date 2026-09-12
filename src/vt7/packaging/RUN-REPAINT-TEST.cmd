@echo off
setlocal
cd /d "%~dp0"
set "vt7_exit=0"
for %%R in (atlas-d3d-hardware atlas-d3d-warp atlas-d2d-hardware atlas-d2d-warp) do call :test %%R
start "" /wait "VT7.Host.exe" --repaint-test --renderer atlas-d3d-warp --inject-repaint-failure --diagnostics-output "%~dp0Logs\repaint-negative.log"
if not errorlevel 1 (
    set "vt7_exit=1"
    echo FAIL: injected pixel mismatch was not rejected.
) else (
    echo Negative run returned failure as expected. Its log must name Atlas differential repaint mismatch.
)
echo Keep the complete Logs folder, including the expected negative report.
pause
exit /b %vt7_exit%

:test
start "" /wait "VT7.Host.exe" --repaint-test --renderer %1 --diagnostics-output "%~dp0Logs\repaint-%1.log"
if errorlevel 1 (
    set "vt7_exit=1"
    echo FAIL: %1. Keep its report and captures.
) else (
    echo PASS: %1
)
exit /b
