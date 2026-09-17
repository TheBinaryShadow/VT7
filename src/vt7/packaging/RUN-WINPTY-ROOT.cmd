@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7SessionOutbound.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%~dp0Logs"
if not "%ERRORLEVEL%"=="0" goto :failed
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7SessionStream.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%~dp0Logs"
if not "%ERRORLEVEL%"=="0" goto :failed
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7WinPtySession.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%~dp0Logs"
if not "%ERRORLEVEL%"=="0" goto :failed
echo VT7 3B.1 WinPTY root validation passed.
echo You can now run RUN-VT7-COMMAND-PROMPT.cmd for the manual interaction check.
if not defined VT7_TEST_NO_PAUSE pause
exit /b 0

:failed
set "VT7_EXIT=%ERRORLEVEL%"
echo VT7 3B.1 WinPTY root validation failed with exit code %VT7_EXIT%.
if not defined VT7_TEST_NO_PAUSE pause
exit /b %VT7_EXIT%
