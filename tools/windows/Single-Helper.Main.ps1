param([ValidateSet('zh','en')][string]$Language='zh',[string]$SelfPath,[switch]$FunctionsOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Language=$Language
$script:Messages=@{
 Ready=@('现在已经就绪，正在监视进程。请启动官方 ISE 安装程序。','Ready and monitoring. Start the official ISE installer now.')
 Found=@('已识别官方 ISE 安装程序。','Official ISE installer detected.')
 Monitoring=@('正在监视安装进度。','Monitoring installation progress.')
 Root=@('安装目录：{0}','Installation folder: {0}')
 WebTalkDone=@('已结束 WebTalk，安装继续。','WebTalk closed. Installation can continue.')
 EqualizerWait=@('正在检查 Version Equalizer（{0} 秒）。','Checking Version Equalizer ({0} seconds).')
 EqualizerDone=@('已结束停留的 Version Equalizer 任务，安装继续。','Stalled Version Equalizer task closed. Installation can continue.')
 InstallerClosed=@('安装程序已退出，正在检查结果。','Installer closed. Checking results.')
 Preparing=@('正在准备并校验修复文件。','Preparing and verifying repair files.')
 Generating=@('正在从官方安装文件生成修复副本。','Generating repair copies from official installation files.')
 PatchSource=@('DLL 修复方案：czietz（2022），本机重现原帖补丁并校验。','DLL fix by czietz (2022): reproducing and verifying the original hotfix locally.')
 Verified=@('修复文件校验通过。','Repair files verified.')
 WaitApps=@('请关闭 ISE 和许可证管理器，随后自动修复。','Close ISE and License Manager to continue automatic repair.')
 Repairing=@('正在备份原文件并修复 DLL。','Backing up original files and repairing DLLs.')
 FileDone=@('已替换并校验：{0}','Replaced and verified: {0}')
 RepairDone=@('DLL 修复完成，共 {0} 个文件。','DLL repair complete: {0} files.')
 EnvironmentDone=@('已设置 ISE 启动检查变量。','ISE startup check variable configured.')
 AlreadyDone=@('DLL 已修复，原始备份已保留。','DLLs are already repaired. Original backups retained.')
 CheckDone=@('检查完成，{0} 个文件需要修复。','Check complete: {0} files need repair.')
 Restored=@('已恢复：{0}','Restored: {0}')
 RestoreDone=@('恢复完成。','Restore complete.')
 Done=@('安装与修复完成，可以启动 ISE。','Installation and repair complete. You can start ISE.')
 Error=@('处理失败：{0}','Failed: {0}')
 Close=@('按 Enter 关闭。','Press Enter to close.')
 Timeout=@('等待超时，请重新打开辅助程序。','Timed out. Reopen the helper.')
 Multiple=@('检测到多个安装器，请关闭多余实例。','Multiple installers detected. Close extra instances.')
 Signature=@('安装器签名或安装包结构不匹配。','Installer signature or package layout does not match.')
 NoRoot=@('未能确认本次安装目录。','Could not identify this installation folder.')
 NotComplete=@('安装尚未成功完成，请检查安装窗口和日志。','Installation did not complete successfully. Check the installer and log.')
 Hash=@('修复文件校验失败。','Repair file verification failed.')
 Baseline=@('官方 DLL 版本不匹配：{0}','Official DLL version does not match: {0}')
 AppsTimeout=@('ISE 或许可证管理器仍在运行，请关闭后重新修复。','ISE or License Manager is still running. Close it before repairing.')
}
function Text([string]$Key,[object[]]$Values=@()) {
    $index=if($script:Language -eq 'zh'){0}else{1}
    return [string]::Format($script:Messages[$Key][$index],$Values)
}
function Say([string]$Key,[object[]]$Values=@()) {
    $line=Text $Key $Values
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'),$line)
    if ($script:SessionLog) { [IO.File]::AppendAllText($script:SessionLog,$line+[Environment]::NewLine) }
}
$script:SessionLog=$null
# Reproduce czietz's 2022 network-enumeration hotfix locally.
# Attribution: https://www.exxosforum.co.uk/forum/viewtopic.php?t=6052#p95891
# Only exact known inputs are accepted; output must match the verified original attachment.
function New-LocalHotfix([string]$InstallRoot,[string]$Destination) {
    $specs=@(
        @{Arch='nt';Relative='ISE\lib\nt\libPortability.dll';Before='F262130EE8493AA1E50EA4A5111CF2BFFD316745DB76FEE92A0CB609831E33D2';After='6B36659BDF3207271B33057E6C6E61E3B3D734AFFD6A7CFC80672B8B3A73B07B';Offset=0x17f30;Bytes=[byte[]]@(0xfe)},
        @{Arch='nt64';Relative='ISE\lib\nt64\libPortabilityNOSH.dll';Before='259844305A4F010E202BAB4A5AF1C08440F6C7503BEBBBD5127A40F88A63F5D8';After='F31D61BAE911A382DF552EE477B07F52729FC65B414F85617188591147BFA1E6';Offset=0x1ab30;Bytes=[byte[]]@(0xbb,0x60,0x09,0x00,0x00,0x48,0x8b,0xcb,0x8b,0xf9)}
    )
    $copies=@{}
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        foreach($spec in $specs) {
            $source=Join-Path $InstallRoot $spec.Relative
            $data=[IO.File]::ReadAllBytes($source)
            $hash=[BitConverter]::ToString($sha.ComputeHash($data)).Replace('-','')
            if($hash -eq $spec.Before) {
                [Array]::Copy($spec.Bytes,0,$data,$spec.Offset,$spec.Bytes.Length)
            } elseif($hash -ne $spec.After) { throw (Text 'Baseline' $spec.Relative) }
            $hash=[BitConverter]::ToString($sha.ComputeHash($data)).Replace('-','')
            if($hash -ne $spec.After) { throw (Text 'Hash') }
            $copies[$spec.Arch]=$data
        }
    } finally { $sha.Dispose() }
    foreach($arch in @('nt','nt64')) {
        $folder=Join-Path $Destination $arch
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $folder 'libPortability.dll'),$copies[$arch])
    }
}
# INSERT_CORE
if ($FunctionsOnly) { return }
$exitCode=1
try {
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if (-not $SelfPath -or $SelfPath.Contains('"')) { throw 'Open the CMD helper.' }
        $null=Start-Process -FilePath $env:ComSpec -Verb RunAs -WindowStyle Normal -ArgumentList ('/d /s /c ""'+$SelfPath+'""') -PassThru
        exit 0
    }
    $session=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('ISE-Modern-Setup\sessions\'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $session -Force | Out-Null
    $script:SessionLog=Join-Path $session 'helper.log'
    Say 'Ready'
    $deadline=(Get-Date).AddHours(1)
    $setup=$null
    while ($null -eq $setup) {
        if ((Get-Date) -gt $deadline) { throw (Text 'Timeout') }
        $candidates=@(Get-NativeSetupCandidate -Processes @(Get-CimInstance Win32_Process))
        if($candidates.Count -gt 1){throw (Text 'Multiple')}
        if($candidates.Count -eq 1){
            $candidate=$candidates[0];$path=$candidate.ExecutablePath
            $setup=[Diagnostics.Process]::GetProcessById([int]$candidate.ProcessId)
            $null=$setup.Handle
            $started=([datetime]$candidate.CreationDate).ToUniversalTime()
        }else{Start-Sleep -Seconds 2}
    }
    if (-not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') }
    $signature=Get-AuthenticodeSignature -LiteralPath $path
    $package=Split-Path (Split-Path (Split-Path -LiteralPath $path))
    if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Xilinx' -or -not(Test-Path -LiteralPath (Join-Path $package 'ise')) -or -not(Test-Path -LiteralPath (Join-Path $package 'idata'))){throw (Text 'Signature')}
    Say 'Found'
    $result=Invoke-Monitor -SetupProcessId $setup.Id -ExpectedSetupPath $path -HandleVersionEqualizer -TimeoutSeconds 3600
    $setup.WaitForExit()
    if(-not $result.Root){throw (Text 'NoRoot')}
    $root=$result.Root
    $log=Join-Path $root '.xinstall\install_debug.log'
    $present=(Test-Path -LiteralPath (Join-Path $root 'settings64.bat')) -and (Test-Path -LiteralPath (Join-Path $root 'ISE\bin\nt64\ise.exe'))
    if(-not(Test-Path -LiteralPath $log) -or $null -eq $setup.ExitCode){throw (Text 'NotComplete')}
    if(-not(Test-InstallCompleted -LogText (Get-Content -LiteralPath $log -Raw) -ExitCode $setup.ExitCode -FilesPresent $present -FreshLog ((Get-Item -LiteralPath $log).LastWriteTimeUtc -ge $started))){throw (Text 'NotComplete')}
    $null=Move-PreviousRepairBackup -InstallRoot $root -NewInstallationStartUtc $started
    $names=@('xsetup','xwebtalk','ise','_pn','xlcm','_xlcm','isimgui','impact','_impact4','planAhead','fuse','isim','xst','map','par','bitgen')
    $deadline=(Get-Date).AddMinutes(10);$announced=$false
    while(@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$names -contains $_.ProcessName}).Count){
        if((Get-Date) -gt $deadline){throw (Text 'AppsTimeout')}
        if(-not $announced){Say 'WaitApps';$announced=$true}
        Start-Sleep -Seconds 2
    }
    Say 'Preparing'
    Say 'PatchSource'
    Say 'Generating'
    $hotfix=Join-Path $session 'hotfix'
    New-LocalHotfix -InstallRoot $root -Destination $hotfix
    if (-not (Test-Hotfix $hotfix)) { throw (Text 'Hash') }
    Say 'Verified'
    Say 'Repairing'
    $repairResult=Invoke-Repair -Mode Apply -InstallRoot $root -HotfixRoot $hotfix
    if($repairResult -ne 0){throw 'DLL repair failed. See helper.log.'}
    Say 'Done';$exitCode=0
}catch{Say 'Error' $_.Exception.Message}
$null=Read-Host (Text 'Close')
exit $exitCode
