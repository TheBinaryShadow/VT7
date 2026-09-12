@echo off
setlocal
cd /d "%~dp0"
echo This test does NOT change Windows display settings.
echo Enter the scaling currently selected in Windows:
choice /c 123 /n /m "1 = 100 percent, 2 = 125 percent, 3 = 150 percent: "
if errorlevel 4 exit /b 2
if errorlevel 3 (set "vt7_dpi=144") else if errorlevel 2 (set "vt7_dpi=120") else if errorlevel 1 (set "vt7_dpi=96") else exit /b 2

:run
set "vt7_exit=0"
for %%R in (atlas-auto atlas-d3d-hardware atlas-d3d-warp atlas-d2d-hardware atlas-d2d-warp) do call :test %%R
echo Reports and four captures per mode: %~dp0Logs
echo Preserve each scaling run. Renderer overrides inside this test are simulations.
pause
exit /b %vt7_exit%

:test
start "" /wait "VT7.Host.exe" --settings-test --renderer %1 --expected-system-dpi %vt7_dpi% --diagnostics-output "%~dp0Logs\settings-dpi%vt7_dpi%-%1.log"
if errorlevel 1 (
    set "vt7_exit=1"
    echo FAIL: %1 at expected DPI %vt7_dpi%. Keep the report.
) else (
    echo PASS: %1 at system DPI %vt7_dpi%
)
exit /b
