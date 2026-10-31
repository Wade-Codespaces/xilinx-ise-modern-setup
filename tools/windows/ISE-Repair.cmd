@echo off
setlocal
echo ISE Modern Setup 0.2 - experimental repair
echo 1. Check (read only)
echo 2. Apply (backup first)
echo 3. Restore
set /p "choice=Choose 1/2/3: "
set "mode="
if "%choice%"=="1" set "mode=Check"
if "%choice%"=="2" set "mode=Apply"
if "%choice%"=="3" set "mode=Restore"
if not defined mode exit /b 1
echo Enter the full ISE_DS folder path without quotation marks.
set /p "iseRoot=ISE_DS: "
if not defined iseRoot exit /b 1
echo Optional: enter the hotfix folder containing nt and nt64, without quotation marks.
echo Leave blank for bundled NOSH only. Restore uses its saved journal.
set /p "hotfixRoot=Hotfix folder: "
if defined hotfixRoot (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-ISE.ps1" -Mode %mode% -InstallRoot "%iseRoot%" -HotfixRoot "%hotfixRoot%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-ISE.ps1" -Mode %mode% -InstallRoot "%iseRoot%"
)
pause
