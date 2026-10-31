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
Import-Module (Join-Path $PSScriptRoot 'WebTalk.Core.psm1') -Force
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
    Write-Status "Watching installer PID $SetupProcessId for up to $TimeoutSeconds seconds. Ctrl+C cancels only the watcher."
    while ((Get-Date) -lt $deadline) {
        $snapshot = @(Get-CimInstance Win32_Process)
        $alive = @($snapshot | Where-Object { $_.ProcessId -eq $SetupProcessId -and [datetime]$_.CreationDate -eq $born })
        if ($alive.Count -ne 1) {
            Write-Status "Installer exited. WebTalk processes stopped: $stopped. This does not prove installation succeeded."
            exit 0
        }
        if ($HandleVersionEqualizer -and -not $InstallRoot) {
            $roots=@(Get-InstallationRoots -Processes $snapshot -SetupProcessId $SetupProcessId -SetupCreationDate $born)
            if ($roots.Count -gt 1) { throw 'Multiple installation roots in selected installer process tree; refusing to guess.' }
            if ($roots.Count -eq 1) {
                $InstallRoot=$roots[0]
                $debugLog=Join-Path $InstallRoot '.xinstall\install_debug.log'
                if ($DiscoveryPath) { [pscustomobject]@{ Root=$InstallRoot; SetupProcessId=$SetupProcessId; CreatedUtc=$born.ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $DiscoveryPath -Encoding UTF8 }
                Write-Status "Detected installation root from installer child: $InstallRoot"
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
            Write-Status "STOPPED installation WebTalk PID $($match.ProcessId). Installer preserved."
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
                    Write-Status "Version Equalizer candidate PID $($candidate.ProcessId); observing $IdleSeconds seconds without CPU/I/O/log changes."
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
                        Write-Status "STOPPED stalled Version Equalizer Perl PID $($candidate.ProcessId). System Generator configuration still requires validation. Installer preserved."
                    }
                }
            } else { $idleToken = '' }
        }
        Start-Sleep -Seconds 2
    }
    Write-Status "TIMEOUT: watcher stopped; installer preserved. WebTalk processes stopped: $stopped."
    exit 2
} catch {
    Write-Status "FAILED: $($_.Exception.Message)"
    exit 1
}
