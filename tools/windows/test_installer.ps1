$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Installer.Core.psm1') -Force
$success='DEBUG:: Installation process finished.'+"`n"+'INFO :: Xilinx Installer/Updater exited with return status "0".'
if (-not (Test-InstallCompleted $success 0 $true $true)) { throw 'Success rejected.' }
foreach ($case in @(
    @('cancelled',0,$true,$true),@($success,1,$true,$true),@($success,0,$false,$true),@($success,0,$true,$false),
    @('Xilinx Installer/Updater exited with return status "0".',0,$true,$true))) {
    if (Test-InstallCompleted $case[0] $case[1] $case[2] $case[3]) { throw 'Cancellation/failure/stale/incomplete installation accepted.' }
}
$testRoot=Join-Path $PSScriptRoot ('..\..\local\repair-tests\orchestration-'+[guid]::NewGuid().ToString('N'))
$testRoot=[IO.Path]::GetFullPath($testRoot)
$root=Join-Path $testRoot 'ISE_DS'
$backup=Join-Path $root '.ise-modern-repair'
New-Item -ItemType Directory -Path $backup -Force | Out-Null
[pscustomobject]@{Version=1;Root=$root} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'state.json')
[IO.File]::WriteAllBytes((Join-Path $backup '0.bin'),[byte[]]@(0,1,2,255))
$archived=Move-PreviousRepairBackup $root
if ((Test-Path -LiteralPath $backup) -or -not (Test-Path -LiteralPath $archived) -or
    ([IO.File]::ReadAllBytes((Join-Path $archived '0.bin')) -join ',') -ne '0,1,2,255') { throw 'Previous backup not preserved exactly.' }
New-Item -ItemType Directory -Path $backup | Out-Null
[pscustomobject]@{Version=1;Root=$root} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'state.json')
Set-Content -LiteralPath (Join-Path $root 'settings64.bat') -Value 'installed'
$refused=$false
try { Move-PreviousRepairBackup $root | Out-Null } catch { $refused=$true }
if (-not $refused -or -not (Test-Path -LiteralPath $backup)) { throw 'Live installation backup moved.' }
$parseErrors=$null
foreach ($script in @('Install-ISE.ps1','Watch-ISE-WebTalk.ps1')) {
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $script),[ref]$null,[ref]$parseErrors) | Out-Null
    if ($parseErrors.Count) { throw "Syntax error in $script" }
}
Write-Host 'PASS: successful exit evidence, cancellation/failure/stale log/missing files blocked; previous backup preserved; live installation journal refused; scripts parse. No real installer launched.'
$candidates=@(
    [pscustomobject]@{Name='xsetup.exe';ExecutablePath='D:\official\bin\nt64\xsetup.exe';CommandLine='"D:\official\bin\nt64\xsetup.exe"';ProcessId=11},
    [pscustomobject]@{Name='xsetup.exe';ExecutablePath='C:\ISE_DS\.xinstall\bin\nt64\xsetup.exe';CommandLine='xsetup.exe -uninstall';ProcessId=12},
    [pscustomobject]@{Name='xsetup.exe';ExecutablePath='D:\official\bin\nt64\xsetup.exe';CommandLine='xsetup.exe -uninstall';ProcessId=13},
    [pscustomobject]@{Name='xsetup.exe';ExecutablePath='D:\official\xsetup.exe';CommandLine='xsetup.exe';ProcessId=14},
    [pscustomobject]@{Name='xsetup.exe';ExecutablePath=$null;CommandLine=$null;ProcessId=15})
$selected=@(Get-NativeSetupCandidate $candidates)
if ($selected.Count -ne 1 -or $selected[0].ProcessId -ne 11) { throw 'Installer discovery incorrectly selected a bootstrapper/uninstaller/unknown process.' }
$archived=Move-PreviousRepairBackup $root -NewInstallationStartUtc ([datetime]::UtcNow.AddMinutes(1))
if (-not (Test-Path -LiteralPath $archived)) { throw 'Previous session journal not preserved after confirmed new installation.' }
Write-Host 'PASS: detects native wizard from process metadata; excludes bootstrapper, uninstall mode, hidden path; retains prior-session backup.'
$launched=Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList @('-NoProfile','-Command','Start-Sleep -Milliseconds 700; exit 0') -WindowStyle Hidden -PassThru
$attached=[Diagnostics.Process]::GetProcessById($launched.Id)
$null=$attached.Handle
$attached.WaitForExit()
if ($null -eq $attached.ExitCode -or $attached.ExitCode -ne 0) { throw 'External process exit code unavailable.' }
$attached.Dispose();$launched.Dispose()
Write-Host 'PASS: attach to an externally started test process and retain its exit code. No installer or system settings changed.'
