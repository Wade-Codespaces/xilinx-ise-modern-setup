[CmdletBinding()]
param([string]$InstallerPath, [string]$InstallRoot, [string]$HotfixRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Installer.Core.psm1') -Force
function Quote-Argument([string]$Value) {
    if ($Value.Contains('"') -or $Value.Contains("`n") -or $Value.EndsWith('\')) { throw 'Enter a full path without quotes or trailing slash.' }
    return '"'+$Value+'"'
}
function Test-Hotfix([string]$Root) {
    $hashes=@{nt='6B36659BDF3207271B33057E6C6E61E3B3D734AFFD6A7CFC80672B8B3A73B07B';nt64='F31D61BAE911A382DF552EE477B07F52729FC65B414F85617188591147BFA1E6'}
    foreach ($arch in @('nt','nt64')) {
        $file=Join-Path $Root "$arch\libPortability.dll"
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return $false }
        $s=[IO.File]::OpenRead($file); $sha=[Security.Cryptography.SHA256]::Create()
        try { $hash=[BitConverter]::ToString($sha.ComputeHash($s)).Replace('-','') } finally { $s.Dispose();$sha.Dispose() }
        if ($hash -ne $hashes[$arch]) { return $false }
    }
    return $true
}
try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $argsList=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Quote-Argument $PSCommandPath))
        foreach ($entry in @(@('InstallerPath',$InstallerPath),@('InstallRoot',$InstallRoot),@('HotfixRoot',$HotfixRoot))) {
            if ($entry[1]) { $argsList+=('-'+$entry[0]); $argsList+=(Quote-Argument $entry[1]) }
        }
        $elevated=Start-Process -FilePath "$PSHOME\powershell.exe" -Verb RunAs -WindowStyle Normal -ArgumentList $argsList -PassThru -Wait
        exit $elevated.ExitCode
    }
    Write-Host 'ISE Modern Setup 0.6 - installation and repair assistant'
    Write-Host 'Wizard choices, license agreements and MATLAB association remain yours.'
    $attachMode=-not $InstallerPath
    $setup=$null
    if ($attachMode) {
        Write-Host 'Waiting for the official native ISE installer. Open xsetup.exe yourself; no installer path is required.'
        $waitDeadline=(Get-Date).AddHours(1)
        while ($null -eq $setup) {
            if ((Get-Date) -gt $waitDeadline) { throw 'No unique native installer detected within one hour. No processes changed.' }
            $candidates=@(Get-NativeSetupCandidate -Processes @(Get-CimInstance Win32_Process))
            if ($candidates.Count -gt 1) { throw 'Multiple native ISE installers detected. Close extra installers and restart this helper.' }
            if ($candidates.Count -eq 1) {
                $candidate=$candidates[0]
                $InstallerPath=$candidate.ExecutablePath
                $setup=[Diagnostics.Process]::GetProcessById([int]$candidate.ProcessId)
                $null=$setup.Handle
                $launched=([datetime]$candidate.CreationDate).ToUniversalTime()
            } else { Start-Sleep -Seconds 2 }
        }
    }
    $InstallerPath=(Resolve-Path -LiteralPath $InstallerPath).ProviderPath
    $direct=Join-Path (Split-Path -LiteralPath $InstallerPath) 'bin\nt64\xsetup.exe'
    if (Test-Path -LiteralPath $direct -PathType Leaf) { $InstallerPath=$direct }
    if ($InstallerPath -notmatch '\\bin\\nt64\\xsetup\.exe$') { throw 'Select native package xsetup.exe or bin/nt64/xsetup.exe.' }
    $packageRoot=Split-Path (Split-Path (Split-Path -LiteralPath $InstallerPath))
    if (-not (Test-Path -LiteralPath (Join-Path $packageRoot 'ise') -PathType Container) -or
        -not (Test-Path -LiteralPath (Join-Path $packageRoot 'idata') -PathType Container)) { throw 'Native full ISE package layout not found. No processes changed.' }
    if (-not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') }
    $signature=Get-AuthenticodeSignature -LiteralPath $InstallerPath
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Xilinx') { throw 'Expected a valid Xilinx-signed installer.' }
    if ($InstallRoot) {
        $InstallRoot=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
        if ([IO.Path]::GetFileName($InstallRoot) -ine 'ISE_DS') { throw 'Target must be the full ISE_DS folder.' }
    }
    if (-not $attachMode -and @(Get-Process -Name xsetup -ErrorAction SilentlyContinue).Count) { throw 'Another installer/uninstaller is running.' }
    if (-not $attachMode -and $InstallRoot -and (Test-Path -LiteralPath (Join-Path $InstallRoot 'ISE\bin\nt64\ise.exe'))) { throw 'ISE is already installed here. Use standalone repair or uninstall first.' }
    $session=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('ISE-Modern-Setup\sessions\'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $session -Force | Out-Null
    if (-not $HotfixRoot) {
        $dl=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
        $candidate=Join-Path ([Environment]::ExpandEnvironmentVariables($dl)) 'xilinx-ise-win10-hang-hotfix-2\xilinx-ise-win10-hang-hotfix-2'
        if (Test-Hotfix $candidate) { $HotfixRoot=$candidate }
    }
    if (-not $HotfixRoot) {
        Write-Host 'Downloading original-author attachment; both DLL hashes must match before installation.'
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        $zip=Join-Path $session 'hotfix.zip'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://www.exxosforum.co.uk/forum/download/file.php?id=29188' -OutFile $zip
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $HotfixRoot=Join-Path $session 'hotfix'
        $bundle=[IO.Compression.ZipFile]::OpenRead($zip)
        try {
            foreach ($arch in @('nt','nt64')) {
                $entry=$bundle.GetEntry("$arch/libPortability.dll")
                if ($null -eq $entry -or $entry.Length -gt 2000000) { throw 'Unexpected attachment contents.' }
                $dest=Join-Path $HotfixRoot $arch
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
                $inputStream=$entry.Open();$outputStream=[IO.File]::Create((Join-Path $dest 'libPortability.dll'))
                try { $inputStream.CopyTo($outputStream) } finally { $inputStream.Dispose();$outputStream.Dispose() }
            }
        } finally { $bundle.Dispose() }
    }
    if (-not (Test-Hotfix $HotfixRoot)) { throw 'Hotfix checksum failed. Installer not launched.' }
    $archive=if (-not $attachMode -and $InstallRoot) { Move-PreviousRepairBackup -InstallRoot $InstallRoot }
    if ($archive) { Write-Host "Previous repair backup preserved: $archive" }
    if ($InstallRoot) { Write-Host "Expected installation base: $(Split-Path (Split-Path $InstallRoot))" }
    Write-Host 'Leave R2026a MATLAB association unchecked. Close License Manager if it opens before automatic repair.'
    $env:XILINX_VC_CHECK_NOOP='1'
    if (-not $attachMode) {
        $launched=(Get-Date).ToUniversalTime()
        $packageRoot=Split-Path (Split-Path (Split-Path -LiteralPath $InstallerPath))
        $setup=Start-Process -FilePath $InstallerPath -WorkingDirectory $packageRoot -WindowStyle Normal -PassThru
    }
    $discovery=Join-Path $session 'installation-root.json'
    $watchArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Quote-Argument (Join-Path $PSScriptRoot 'Watch-ISE-WebTalk.ps1')),'-SetupProcessId',[string]$setup.Id,'-ExpectedSetupPath',(Quote-Argument $InstallerPath),'-HandleVersionEqualizer','-DiscoveryPath',(Quote-Argument $discovery),'-TimeoutSeconds','3600','-LogPath',(Quote-Argument (Join-Path $session 'installer-helper.log')))
    if ($InstallRoot) { $watchArgs+=@('-InstallRoot',(Quote-Argument $InstallRoot)) }
    $watch=Start-Process -FilePath "$PSHOME\powershell.exe" -WindowStyle Hidden -ArgumentList $watchArgs -PassThru
    Write-Host "Installer and helper running. Logs: $session"
    Write-Host 'Finish and exit the official wizard to trigger DLL repair. Cancelling will not trigger repair.'
    while (-not $setup.HasExited) { Start-Sleep -Seconds 2; $setup.Refresh() }
    $setup.WaitForExit()
    if (-not $InstallRoot) {
        if (Test-Path -LiteralPath $discovery) {
            $detected=Get-Content -LiteralPath $discovery -Raw | ConvertFrom-Json
            if ($detected.SetupProcessId -ne $setup.Id) { throw 'Discovery record belongs to another installer.' }
            $InstallRoot=[IO.Path]::GetFullPath($detected.Root).TrimEnd('\')
        } else { throw 'Installation root could not be confirmed from this installer. No DLLs replaced.' }
    }
    $log=Join-Path $InstallRoot '.xinstall\install_debug.log'
    $filesPresent=(Test-Path -LiteralPath (Join-Path $InstallRoot 'settings64.bat')) -and (Test-Path -LiteralPath (Join-Path $InstallRoot 'ISE\bin\nt64\ise.exe'))
    $logText='';$fresh=$false
    if (Test-Path -LiteralPath $log) { $fresh=(Get-Item -LiteralPath $log).LastWriteTimeUtc -ge $launched; $logText=Get-Content -LiteralPath $log -Raw }
    if ($null -eq $setup.ExitCode -or -not (Test-InstallCompleted -LogText $logText -ExitCode $setup.ExitCode -FilesPresent $filesPresent -FreshLog $fresh)) { throw 'Successful installation not confirmed. No DLLs replaced. Check path/wizard result/logs.' }
    $archive=Move-PreviousRepairBackup -InstallRoot $InstallRoot -NewInstallationStartUtc $launched
    if ($archive) { Write-Host "Previous installation backup preserved: $archive" }
    $deadline=(Get-Date).AddMinutes(10)
    $names=@('xsetup','xwebtalk','ise','_pn','xlcm','_xlcm','isimgui','impact','_impact4','planAhead','fuse','isim','xst','map','par','bitgen')
    while (@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.ProcessName }).Count) {
        if ((Get-Date) -gt $deadline) { throw 'Xilinx apps still open; close them and use standalone repair. DLLs not changed.' }
        Write-Host 'Waiting for Xilinx apps/License Manager to close; no apps are forcibly closed.'
        Start-Sleep -Seconds 5
    }
    $repairArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Quote-Argument (Join-Path $PSScriptRoot 'Repair-ISE.ps1')),'-Mode','Apply','-InstallRoot',(Quote-Argument $InstallRoot),'-HotfixRoot',(Quote-Argument $HotfixRoot))
    $repair=Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList $repairArgs -NoNewWindow -PassThru -Wait
    if ($repair.ExitCode -ne 0) { throw 'Automatic DLL repair failed. Logs and backups retained.' }
    Write-Host 'DONE: official installation and verified DLL replacement completed. Application functionality still needs validation.'
    if (Test-Path -LiteralPath (Join-Path $InstallRoot '.xinstall\version-equalizer-recovery.json')) { Write-Host 'NOTE: Version Equalizer bypassed; System Generator configuration needs review.' }
    exit 0
} catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
