@echo off
setlocal
cd /d "%~dp0"
set "VT7_OUTPUT=%~dp0Logs"
if defined VT7_TEST_OUTPUT_DIRECTORY set "VT7_OUTPUT=%VT7_TEST_OUTPUT_DIRECTORY%"
set "VT7_OPENSSH_VERSION=10.0.0.0"
if defined VT7_TEST_EXPECTED_SSH_KEYGEN_FILE_VERSION set "VT7_OPENSSH_VERSION=%VT7_TEST_EXPECTED_SSH_KEYGEN_FILE_VERSION%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-VT7KnownHosts.ps1" -Configuration Release -BinaryDirectory "%~dp0." -OutputDirectory "%VT7_OUTPUT%" -ExpectedSshKeygenFileVersion "%VT7_OPENSSH_VERSION%"
set "code=%errorlevel%"
if not "%code%"=="0" echo VT7 KH01.3 first-contact known-host validation failed with exit code %code%.
if "%code%"=="0" echo VT7 KH01.3 first-contact known-host validation passed.
if not defined VT7_TEST_NO_PAUSE pause
exit /b %code%
