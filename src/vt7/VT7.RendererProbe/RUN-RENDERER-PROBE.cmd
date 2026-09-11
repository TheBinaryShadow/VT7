@echo off
setlocal
cd /d "%~dp0"
"%~dp0VT7.RendererProbe.exe" --output "%~dp0VT7-renderer-probe.log"
set "vt7_exit=%ERRORLEVEL%"
if "%vt7_exit%"=="0" (
    echo VT7 renderer capability baseline passed. This is not Atlas acceptance.
) else (
    echo VT7 renderer capability probe failed with exit code %vt7_exit%.
)
echo Report: %~dp0VT7-renderer-probe.log
echo Font comparison: %~dp0VT7-renderer-probe.log.bmp
echo Geometry comparisons: %~dp0VT7-renderer-probe.log.bmp.geometry-*.bmp
echo Repaint comparisons: %~dp0VT7-renderer-probe.log.bmp.repaint-*.bmp
echo Adapter comparisons: %~dp0VT7-renderer-probe.log.bmp.adapter-*.bmp
echo Horizontal fitting: %~dp0VT7-renderer-probe.log.bmp.horizontal-*.bmp
echo Arabic context/order: %~dp0VT7-renderer-probe.log.bmp.arabic-*.bmp
echo Joined Arabic spans: %~dp0VT7-renderer-probe.log.bmp.joined-*.bmp
echo Cross-style lam-alef: %~dp0VT7-renderer-probe.log.bmp.ligature-*.bmp
echo Marked paint and selection: %~dp0VT7-renderer-probe.log.bmp.paint-*.bmp
echo Send the log and all generated bitmaps, including if the baseline fails.
pause
exit /b %vt7_exit%
