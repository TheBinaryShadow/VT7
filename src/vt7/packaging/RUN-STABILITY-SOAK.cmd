@echo off
setlocal
cd /d "%~dp0"
echo Extended hardware and WARP tests take approximately 90 minutes in total.
echo Each mode runs 100 lifecycle cycles, 30 minutes active, then 10 minutes idle.
echo Keep Windows awake. Do not change display settings during the test.
echo Live progress is written under Logs. Closing this launcher does not cancel VT7.Host.
choice /c YN /n /m "Run the extended tests? Y/N: "
if errorlevel 2 exit /b 2
set "vt7_exit=0"
for %%R in (atlas-d3d-hardware atlas-d3d-warp) do call :test %%R
echo Keep all reports and progress logs: %~dp0Logs
pause
exit /b %vt7_exit%
:test
start "" /wait "VT7.Host.exe" --stability-test --stability-soak --renderer %1 --diagnostics-output "%~dp0Logs\stability-extended-%1.log"
if errorlevel 1 (set "vt7_exit=1" & echo FAIL: %1) else echo PASS: %1
exit /b
