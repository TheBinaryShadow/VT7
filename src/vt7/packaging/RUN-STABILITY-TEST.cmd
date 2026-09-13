@echo off
setlocal
cd /d "%~dp0"
set "vt7_exit=0"
for %%R in (atlas-d3d-hardware atlas-d3d-warp) do call :test %%R
echo Quick scheduling/stability reports and live progress: %~dp0Logs
echo This does not replace the extended soak. Keep all reports.
pause
exit /b %vt7_exit%
:test
start "" /wait "VT7.Host.exe" --stability-test --renderer %1 --diagnostics-output "%~dp0Logs\stability-quick-%1.log"
if errorlevel 1 (set "vt7_exit=1" & echo FAIL: %1) else echo PASS: %1
exit /b
