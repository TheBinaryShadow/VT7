@echo off
setlocal
cd /d "%~dp0"
echo Bounded hardware and WARP lifecycle checks, approximately 5-10 minutes total.
echo Each mode runs 100 lifecycles, 1000 resizes and 500 tab round trips.
echo Keep all reports, including resource-budget failures. This is not the timed soak.
set "vt7_exit=0"
for %%R in (atlas-d3d-hardware atlas-d3d-warp) do call :test %%R
echo Reports and live progress: %~dp0Logs
pause
exit /b %vt7_exit%
:test
start "" /wait "VT7.Host.exe" --stability-test --stability-lifecycle --renderer %1 --diagnostics-output "%~dp0Logs\stability-lifecycle-%1.log"
if errorlevel 1 (set "vt7_exit=1" & echo FAIL: %1) else echo PASS: %1
exit /b
