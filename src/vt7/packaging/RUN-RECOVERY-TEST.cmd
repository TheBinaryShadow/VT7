@echo off
setlocal
cd /d "%~dp0"
set "vt7_exit=0"
echo Testing INJECTED failures. No driver or system settings will be changed.
call :test atlas-auto startup-hardware
call :test atlas-auto startup-both
call :test atlas-d3d-hardware startup-hardware
call :test atlas-auto present-permanent
call :test atlas-d3d-warp present-permanent
call :test atlas-auto close-retry
for %%R in (atlas-auto atlas-d3d-hardware atlas-d3d-warp atlas-d2d-hardware atlas-d2d-warp) do (
    call :test %%R present-once
    call :test %%R present-twice
)
echo All 16 scenarios should PASS, including expected fatal-state assertions.
echo Keep all recovery logs and PNGs in: %~dp0Logs
pause
exit /b %vt7_exit%

:test
start "" /wait "VT7.Host.exe" --recovery-test %2 --renderer %1 --diagnostics-output "%~dp0Logs\recovery-%1-%2.log"
if errorlevel 1 (
    set "vt7_exit=1"
    echo FAIL: %1 %2. Keep its log and any partial output.
) else (
    echo PASS: %1 %2
)
exit /b
