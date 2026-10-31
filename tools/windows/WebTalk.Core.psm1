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
Export-ModuleMember -Function Get-InstallationWebTalk,Get-VersionEqualizerCandidate,Get-EqualizerActivityToken,Get-InstallationRoots
