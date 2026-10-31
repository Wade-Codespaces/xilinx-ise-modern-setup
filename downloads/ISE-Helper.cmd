@echo off
setlocal DisableDelayedExpansion
set "ISE_HELPER_SELF=%~f0"
set "ISE_HELPER_LANGUAGE=en"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:ISE_HELPER_SELF);$m='#'+'--ISE-POWERSHELL--';& ([scriptblock]::Create($t.Substring($t.IndexOf($m)+$m.Length))) -Language $env:ISE_HELPER_LANGUAGE -SelfPath $env:ISE_HELPER_SELF"
exit /b %errorlevel%
#--ISE-POWERSHELL--
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
Set-StrictMode -Version Latest
function Test-InstallCompleted {
    param([string]$LogText, [int]$ExitCode, [bool]$FilesPresent, [bool]$FreshLog)
    if ($ExitCode -ne 0 -or -not $FilesPresent -or -not $FreshLog) { return $false }
    return $LogText -match '(?s)Installation process finished\..*Xilinx Installer/Updater exited with return status "0"\.'
}
function Move-PreviousRepairBackup {
    param([string]$InstallRoot, [Nullable[datetime]]$NewInstallationStartUtc)
    $root = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
    $backup = Join-Path $root '.ise-modern-repair'
    if (-not (Test-Path -LiteralPath $backup)) { return }
    if ((Test-Path -LiteralPath (Join-Path $root 'settings64.bat')) -or
        (Test-Path -LiteralPath (Join-Path $root 'ISE\bin\nt64\ise.exe'))) {
        if ($null -eq $NewInstallationStartUtc -or
            (Get-Item -LiteralPath (Join-Path $backup 'state.json')).LastWriteTimeUtc -ge $NewInstallationStartUtc) {
            throw 'An installation with a current repair journal is still present. Review/uninstall it first.'
        }
    }
    $item = Get-Item -LiteralPath $backup -Force
    $ancestor=$item
    while ($null -ne $ancestor) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked backup directory/ancestor refused.' }
        $ancestor=$ancestor.Parent
    }
    $state = Get-Content -LiteralPath (Join-Path $backup 'state.json') -Raw | ConvertFrom-Json
    if ($state.Version -ne 1 -or $state.Root -ine $root) { throw 'Previous backup identity mismatch.' }
    $destination = Join-Path $root ('.ise-modern-repair.previous-' + [guid]::NewGuid().ToString('N'))
    if ([IO.Path]::GetDirectoryName($destination) -ine $root -or [IO.Path]::GetDirectoryName($backup) -ine $root) { throw 'Backup archive must remain inside selected installation directory.' }
    [IO.Directory]::Move($backup,$destination)
    return $destination
}
function Get-NativeSetupCandidate {
    param([object[]]$Processes)
    foreach ($p in $Processes) {
        if ($p.Name -ine 'xsetup.exe' -or [string]::IsNullOrWhiteSpace($p.ExecutablePath)) { continue }
        if ($p.ExecutablePath -notmatch '\\bin\\nt64\\xsetup\.exe$' -or
            $p.ExecutablePath -match '\\\.xinstall\\' -or
            [string]::IsNullOrWhiteSpace($p.CommandLine) -or
            $p.CommandLine -match '(?i)(?:^|\s)-(?:uninstall|remove)(?:\s|$)') { continue }
        $p
    }
}

Set-StrictMode -Version Latest
function Get-InstallationWebTalk {
    param([object[]]$Processes, [uint32]$SetupProcessId, [datetime]$SetupCreationDate, [string]$ProcessName = 'xwebtalk.exe')
    $root = @($Processes | Where-Object { $_.ProcessId -eq $SetupProcessId -and $_.Name -ieq 'xsetup.exe' })
    if ($root.Count -ne 1 -or [datetime]$root[0].CreationDate -ne $SetupCreationDate) { return }
    $map = @{}
    foreach ($p in $Processes) { $map[[uint32]$p.ProcessId] = $p }
    foreach ($candidate in $Processes) {
        if ($ProcessName -ne '*' -and $candidate.Name -ine $ProcessName) { continue }
        $node = $candidate
        $seen = @{}
        while ($node.ProcessId -ne $SetupProcessId) {
            $id = [uint32]$node.ProcessId
            if ($seen.ContainsKey($id)) { break }
            $seen[$id] = $true
            $parentId = [uint32]$node.ParentProcessId
            if (-not $map.ContainsKey($parentId)) { break }
            $parent = $map[$parentId]
            if ([datetime]$parent.CreationDate -gt [datetime]$node.CreationDate) { break }
            $node = $parent
        }
        if ($node.ProcessId -eq $SetupProcessId) { $candidate }
    }
}
function Get-VersionEqualizerCandidate {
    param([object[]]$Processes, [uint32]$SetupProcessId, [datetime]$SetupCreationDate,
          [string]$InstallRoot, [string[]]$LogTail)
    $lastExecute = @($LogTail | Where-Object { $_ -match ':: Execute:' } | Select-Object -Last 1)
    if ($lastExecute.Count -ne 1 -or $lastExecute[0] -notmatch ':: Execute: Version Equalizer\s*$') { return }
    $scriptPath = Join-Path $InstallRoot 'ISE\sysgen\util\fix_version.pl'
    $scriptToken = '(?i)(?:^|\s)"?' + [regex]::Escape($scriptPath) + '"?(?:\s|$)'
    foreach ($p in @(Get-InstallationWebTalk -Processes $Processes -SetupProcessId $SetupProcessId -SetupCreationDate $SetupCreationDate -ProcessName 'xilperl.exe')) {
        $paths = @((Join-Path $InstallRoot 'ISE\bin\nt64\xilperl.exe'), (Join-Path $InstallRoot 'ISE\bin\nt\xilperl.exe'))
        if ($p.ExecutablePath -iin $paths -and $p.CommandLine -match $scriptToken) { $p }
    }
}
function Get-EqualizerActivityToken {
    param($Process, [string]$LogStamp)
    # Unknown counters are not evidence of inactivity.
    $values = @($Process.KernelModeTime,$Process.UserModeTime,$Process.ReadTransferCount,$Process.WriteTransferCount)
    if (@($values | Where-Object { $null -eq $_ }).Count) { throw 'Activity counters unavailable; manual review required.' }
    return "$($Process.ProcessId)|$([datetime]$Process.CreationDate)|$($values -join '|')|$LogStamp"
}
function Get-InstallationRoots {
    param([object[]]$Processes,[uint32]$SetupProcessId,[datetime]$SetupCreationDate)
    Get-InstallationWebTalk -Processes $Processes -SetupProcessId $SetupProcessId -SetupCreationDate $SetupCreationDate -ProcessName '*' |
        ForEach-Object { if ($_.ExecutablePath -match '^(?<root>.+\\ISE_DS)\\') { $Matches['root'] } } | Sort-Object -Unique
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
}function Invoke-Repair {
[CmdletBinding()]
param(
    [ValidateSet('Check','Apply','Restore')][string]$Mode = 'Check',
    [Parameter(Mandatory=$true)][string]$InstallRoot,
    [switch]$SkipEnvironment,
    [string]$HotfixRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Hash([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Assert-Regular([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point refused: $($item.FullName)" }
        $item = if ($item -is [IO.DirectoryInfo]) { $item.Parent } else { $item.Directory }
    }
}
function Machine([string]$Path) {
    Assert-Regular $Path
    $s = [IO.File]::OpenRead($Path)
    $b = New-Object IO.BinaryReader($s)
    try {
        if ($b.ReadUInt16() -ne 0x5A4D) { throw "Not a PE file: $Path" }
        $s.Position = 0x3c
        $offset = $b.ReadInt32()
        if ($offset -lt 64 -or $offset -gt ($s.Length - 24)) { throw "Invalid PE header: $Path" }
        $s.Position = $offset
        if ($b.ReadUInt32() -ne 0x4550) { throw "Invalid PE signature: $Path" }
        return $b.ReadUInt16()
    } finally { $b.Dispose(); $s.Dispose() }
}
function Save-State($State) {
    $temp = "$statePath.tmp"
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $statePath -Force
}
function Assert-Idle {
    $names = @('xsetup','xwebtalk','ise','_pn','xlcm','_xlcm','isimgui','impact','_impact4','planAhead','fuse','isim','xst','map','par','bitgen')
    $active = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.ProcessName })
    if ($active.Count) { throw ('Close installer and Xilinx tools first: ' + (($active.ProcessName | Sort-Object -Unique) -join ', ')) }
}

try {
    $root = (Resolve-Path -LiteralPath $InstallRoot).ProviderPath.TrimEnd('\')
    Assert-Regular $root
    if (-not (Test-Path -LiteralPath (Join-Path $root 'ISE\lib\nt64') -PathType Container) -or
        -not (Test-Path -LiteralPath (Join-Path $root 'settings64.bat') -PathType Leaf)) {
        throw 'Choose the ISE_DS folder of a complete native ISE installation.'
    }
    $backupRoot = Join-Path $root '.ise-modern-repair'
    $statePath = Join-Path $backupRoot 'state.json'
    if (Test-Path -LiteralPath $backupRoot) { Assert-Regular $backupRoot }

    $networkFix = -not [string]::IsNullOrWhiteSpace($HotfixRoot)

    if ($Mode -eq 'Restore') {
        Assert-Idle
        Assert-Regular $statePath
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if ($state.Version -ne 1 -or $state.Root -ne $root) { throw 'State does not match this installation.' }
        # Validate the entire journal before writing anything.
        foreach ($f in $state.Files) {
            $target = [IO.Path]::GetFullPath((Join-Path $root $f.Relative))
            if (-not $target.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -or
                [IO.Path]::GetFileName($target) -notin @('libPortability.dll','libPortabilityNOSH.dll') -or
                $f.Backup -notmatch '^\d+\.bin$') { throw 'Invalid journal path.' }
            $backup = Join-Path $backupRoot $f.Backup
            Assert-Regular $backup
            Assert-Regular $target
            if ((Hash $backup) -ne $f.Before) { throw "Backup checksum failed: $($f.Relative)" }
            if ((Hash $target) -notin @($f.Before,$f.After)) { throw "File changed since repair; refusing restore: $($f.Relative)" }
        }
        if ($state.Environment.Enabled) {
            $current = [Environment]::GetEnvironmentVariable('XILINX_VC_CHECK_NOOP','User')
            if ($current -ne '1' -and $current -ne $state.Environment.Before) { throw 'Environment changed since repair; refusing overwrite.' }
        }
        foreach ($f in $state.Files) {
            $target = Join-Path $root $f.Relative
            Copy-Item -LiteralPath (Join-Path $backupRoot $f.Backup) -Destination $target -Force
            if ((Hash $target) -ne $f.Before) { throw "Restore checksum failed: $($f.Relative)" }
            Say 'Restored' $f.Relative
        }
        if ($state.Environment.Enabled) {
            [Environment]::SetEnvironmentVariable('XILINX_VC_CHECK_NOOP',$state.Environment.Before,'User')
        }
        $state.Status = 'Restored'
        Save-State $state
        Say 'RestoreDone'
        return 0
    }
    if ($Mode -eq 'Apply') { Assert-Idle }
    $plan = @()
    foreach ($arch in @('nt','nt64')) {
        $expected = if ($arch -eq 'nt64') { 0x8664 } else { 0x14c }
        $source = Join-Path $root "ISE\lib\$arch\libPortabilityNOSH.dll"
        if ($networkFix) {
            $source = Join-Path $HotfixRoot "$arch\libPortability.dll"
            $knownHash = if ($arch -eq 'nt64') { 'F31D61BAE911A382DF552EE477B07F52729FC65B414F85617188591147BFA1E6' } else { '6B36659BDF3207271B33057E6C6E61E3B3D734AFFD6A7CFC80672B8B3A73B07B' }
            if ((Hash $source) -ne $knownHash) { throw "Unrecognized hotfix checksum: $arch" }
        }
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing official NOSH source: ISE\lib\$arch" }
        if ((Machine $source) -ne $expected) { throw "Source architecture mismatch: $arch" }
        $sourceHash = Hash $source
        $files = @(Get-ChildItem -LiteralPath $root -Filter libPortability.dll -File -Recurse -Force |
            Where-Object { $_.FullName -notlike "$backupRoot\*" -and $_.FullName -match ('\\' + $arch + '(\\|$)') })
        if ($files.Count -eq 0) { throw "No target DLLs found for $arch. Installation may be incomplete." }
        if ($networkFix) {
            $files += @(Get-ChildItem -LiteralPath $root -Filter libPortabilityNOSH.dll -File -Recurse -Force |
                Where-Object { $_.FullName -notlike "$backupRoot\*" -and $_.FullName -match ('\\' + $arch + '(\\|$)') })
        }
        foreach ($file in $files) {
            if ((Machine $file.FullName) -ne $expected) { throw "Target architecture mismatch: $($file.FullName)" }
            $before = Hash $file.FullName
            $relative = $file.FullName.Substring($root.Length + 1)

            if ($before -ne $sourceHash) {
                $plan += [pscustomobject]@{ Relative=$relative; Source=$source; Before=$before; After=$sourceHash; Backup="$($plan.Count).bin" }
            }
        }
    }
    if ($Mode -eq 'Check') {
        Say 'CheckDone' $plan.Count

        return 0
    }
    if (Test-Path -LiteralPath $statePath) {
        $old = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if ($old.Status -eq 'Applied' -and $old.Root -eq $root -and $plan.Count -eq 0 -and
            ($SkipEnvironment -or [Environment]::GetEnvironmentVariable('XILINX_VC_CHECK_NOOP','User') -eq '1')) {
            Say 'AlreadyDone'; return 0
        }
        throw 'Existing repair journal found. Restore/review it before another application.'
    }
    if (Test-Path -LiteralPath $backupRoot) { throw 'Backup directory already exists without a journal; review it first.' }
    New-Item -ItemType Directory -Path $backupRoot | Out-Null
    $state = [pscustomobject]@{
        Version=1; Root=$root; Status='BackingUp'; Files=@($plan); Environment=[pscustomobject]@{
            Enabled=(-not $SkipEnvironment); Before=[Environment]::GetEnvironmentVariable('XILINX_VC_CHECK_NOOP','User')
        }
    }
    # Back up and verify ALL files before modifying the first DLL.
    foreach ($f in $plan) {
        Copy-Item -LiteralPath (Join-Path $root $f.Relative) -Destination (Join-Path $backupRoot $f.Backup)
        if ((Hash (Join-Path $backupRoot $f.Backup)) -ne $f.Before) { throw 'Backup verification failed.' }
    }
    $state.Status = 'Prepared'; Save-State $state
    foreach ($f in $plan) {
        $target = Join-Path $root $f.Relative
        if ((Hash $target) -ne $f.Before -or (Hash $f.Source) -ne $f.After) { throw 'File changed after planning. Use Restore.' }
        Copy-Item -LiteralPath $f.Source -Destination $target -Force
        if ((Hash $target) -ne $f.After) { throw 'Copy verification failed. Use Restore.' }
        Say 'FileDone' $f.Relative
    }
    if (-not $SkipEnvironment) { [Environment]::SetEnvironmentVariable('XILINX_VC_CHECK_NOOP','1','User'); Say 'EnvironmentDone' }
    $state.Status = 'Applied'; Save-State $state
    Say 'RepairDone' $plan.Count
    return 0
} catch {
    Say 'Error' $_.Exception.Message

    return 1
}

}
function Invoke-Monitor {
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][uint32]$SetupProcessId,
    [Parameter(Mandatory=$true)][string]$ExpectedSetupPath,
    [ValidateRange(10,3600)][int]$TimeoutSeconds = 900,
    [ValidateRange(0,120)][int]$GraceSeconds = 10,
    [string]$LogPath,
    [switch]$HandleVersionEqualizer,
    [string]$InstallRoot,
    [ValidateRange(10,600)][int]$IdleSeconds = 30,
    [string]$DiscoveryPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Write-Status([string]$Message) {
    Write-Host $Message
    if ($LogPath) { [IO.File]::AppendAllText($LogPath, ((Get-Date).ToString('o') + ' ' + $Message + [Environment]::NewLine)) }
}
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator privileges required to inspect and stop the elevated installer child. Run WebTalk-Helper.cmd as administrator.'
    }
    $root = Get-CimInstance Win32_Process -Filter "ProcessId=$SetupProcessId"
    $expected = (Resolve-Path -LiteralPath $ExpectedSetupPath).ProviderPath
    if ($null -eq $root -or $root.Name -ine 'xsetup.exe' -or
        [string]::IsNullOrEmpty($root.ExecutablePath) -or $root.ExecutablePath -ine $expected) {
        throw 'Installer identity/path mismatch. No processes changed.'
    }
    $born = [datetime]$root.CreationDate
    if ($HandleVersionEqualizer) {
        $debugLog=''
        if ($InstallRoot) {
            $InstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
            $debugLog = Join-Path $InstallRoot '.xinstall\install_debug.log'
        }
    }
    $idleToken = ''; $idleSince = Get-Date; $equalizerHandled = $false
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $stopped = 0
    Say 'Monitoring'
    while ((Get-Date) -lt $deadline) {
        $snapshot = @(Get-CimInstance Win32_Process)
        $alive = @($snapshot | Where-Object { $_.ProcessId -eq $SetupProcessId -and [datetime]$_.CreationDate -eq $born })
        if ($alive.Count -ne 1) {
            Say 'InstallerClosed'
            return [pscustomobject]@{ Root=$InstallRoot; WebTalk=$stopped; Equalizer=$equalizerHandled }
        }
        if ($HandleVersionEqualizer -and -not $InstallRoot) {
            $roots=@(Get-InstallationRoots -Processes $snapshot -SetupProcessId $SetupProcessId -SetupCreationDate $born)
            if ($roots.Count -gt 1) { throw 'Multiple installation roots in selected installer process tree; refusing to guess.' }
            if ($roots.Count -eq 1) {
                $InstallRoot=$roots[0]
                $debugLog=Join-Path $InstallRoot '.xinstall\install_debug.log'
                if ($DiscoveryPath) { [pscustomobject]@{ Root=$InstallRoot; SetupProcessId=$SetupProcessId; CreatedUtc=$born.ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $DiscoveryPath -Encoding UTF8 }
                Say 'Root' $InstallRoot
            }
        }
        $matches = @(Get-InstallationWebTalk -Processes $snapshot -SetupProcessId $SetupProcessId -SetupCreationDate $born)
        foreach ($match in $matches) {
            if (((Get-Date) - [datetime]$match.CreationDate).TotalSeconds -lt $GraceSeconds) { continue }
            # Recheck lineage, start time and exact executable name immediately before termination.
            $fresh = @(Get-CimInstance Win32_Process)
            $confirmed = @(Get-InstallationWebTalk -Processes $fresh -SetupProcessId $SetupProcessId -SetupCreationDate $born |
                Where-Object { $_.ProcessId -eq $match.ProcessId -and [datetime]$_.CreationDate -eq [datetime]$match.CreationDate })
            if ($confirmed.Count -ne 1) { continue }
            $result = Invoke-CimMethod -InputObject $confirmed[0] -MethodName Terminate -Arguments @{ Reason = [uint32]0 }
            if ($result.ReturnValue -ne 0) { throw "WebTalk termination failed, code $($result.ReturnValue)." }
            $stopped++
            Say 'WebTalkDone'
            if ($stopped -ge 4) { throw 'Four WebTalk instances handled; stopping watcher for manual review.' }
        }
        if ($HandleVersionEqualizer -and $InstallRoot -and -not $equalizerHandled -and
            (Test-Path -LiteralPath $debugLog -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $InstallRoot 'ISE\sysgen\util\fix_version.pl') -PathType Leaf)) {
            $tail = @(Get-Content -LiteralPath $debugLog -Tail 40)
            $candidates = @(Get-VersionEqualizerCandidate -Processes $snapshot -SetupProcessId $SetupProcessId -SetupCreationDate $born -InstallRoot $InstallRoot -LogTail $tail)
            if ($candidates.Count -eq 1) {
                $candidate = $candidates[0]
                $logInfo = Get-Item -LiteralPath $debugLog
                $stamp = "$($logInfo.Length)|$($logInfo.LastWriteTimeUtc.Ticks)"
                $token = Get-EqualizerActivityToken -Process $candidate -LogStamp $stamp
                if ($token -ne $idleToken) {
                    $idleToken = $token; $idleSince = Get-Date
                    Say 'EqualizerWait' $IdleSeconds
                } elseif (((Get-Date) - $idleSince).TotalSeconds -ge $IdleSeconds) {
                    $fresh = @(Get-CimInstance Win32_Process)
                    $latestTail = @(Get-Content -LiteralPath $debugLog -Tail 40)
                    $confirmed = @(Get-VersionEqualizerCandidate -Processes $fresh -SetupProcessId $SetupProcessId -SetupCreationDate $born -InstallRoot $InstallRoot -LogTail $latestTail)
                    $info = Get-Item -LiteralPath $debugLog
                    if ($confirmed.Count -eq 1 -and (Get-EqualizerActivityToken -Process $confirmed[0] -LogStamp "$($info.Length)|$($info.LastWriteTimeUtc.Ticks)") -eq $idleToken) {
                        $recordPath = Join-Path $InstallRoot '.xinstall\version-equalizer-recovery.json'
                        if (Test-Path -LiteralPath $recordPath) { throw 'Previous Equalizer recovery record exists; refusing automatic retry.' }
                        $record = [pscustomobject]@{ Status='Planned'; ProcessId=$candidate.ProcessId; ObservedIdleSeconds=$IdleSeconds; TimeUtc=(Get-Date).ToUniversalTime().ToString('o'); Script='ISE/sysgen/util/fix_version.pl'; Warning='Installation workaround only; System Generator version configuration requires validation.' }
                        $record | ConvertTo-Json | Set-Content -LiteralPath $recordPath -Encoding UTF8
                        $result = Invoke-CimMethod -InputObject $confirmed[0] -MethodName Terminate -Arguments @{ Reason=[uint32]0 }
                        if ($result.ReturnValue -ne 0) { throw "Equalizer termination failed, code $($result.ReturnValue)." }
                        $record.Status = 'Bypassed'; $record | ConvertTo-Json | Set-Content -LiteralPath $recordPath -Encoding UTF8
                        $equalizerHandled = $true
                        Say 'EqualizerDone'
                    }
                }
            } else { $idleToken = '' }
        }
        Start-Sleep -Seconds 2
    }
    throw (Text 'Timeout')
} catch {
    throw
}

}

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
