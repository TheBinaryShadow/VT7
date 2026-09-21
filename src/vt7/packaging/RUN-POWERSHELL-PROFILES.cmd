@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7SessionOutbound.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%~dp0Logs"
if not "%ERRORLEVEL%"=="0" goto :failed
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7SessionStream.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%~dp0Logs"
if not "%ERRORLEVEL%"=="0" goto :failed
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7WinPtySession.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%~dp0Logs"
if not "%ERRORLEVEL%"=="0" goto :failed
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7PowerShellProfiles.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%~dp0Logs"
if not "%ERRORLEVEL%"=="0" goto :failed
echo VT7 3B.2 PowerShell profile validation passed.
echo Continue with both PowerShell launchers and the manual PSReadLine checks in README.txt.
if not defined VT7_TEST_NO_PAUSE pause
exit /b 0

:failed
set "VT7_EXIT=%ERRORLEVEL%"
echo VT7 3B.2 PowerShell profile validation failed with exit code %VT7_EXIT%.
if not defined VT7_TEST_NO_PAUSE pause
exit /b %VT7_EXIT%
