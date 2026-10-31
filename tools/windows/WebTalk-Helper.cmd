@echo off
setlocal
echo Run this helper as administrator while the ISE installer is running.
echo It stops only xwebtalk.exe descendants of the selected xsetup.exe.
set /p "setupId=Installer process ID (PID): "
set /p "setupExe=Exact running xsetup.exe path, without quotes: "
echo Optional: enter ISE_DS folder to also recover a stalled Version Equalizer.
echo This bypasses its stalled script; System Generator configuration needs later validation.
set /p "installRoot=ISE_DS folder (blank for WebTalk only): "
if not defined setupId exit /b 1
if not defined setupExe exit /b 1
if defined installRoot (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Watch-ISE-WebTalk.ps1" -SetupProcessId "%setupId%" -ExpectedSetupPath "%setupExe%" -HandleVersionEqualizer -InstallRoot "%installRoot%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Watch-ISE-WebTalk.ps1" -SetupProcessId "%setupId%" -ExpectedSetupPath "%setupExe%"
)
pause
