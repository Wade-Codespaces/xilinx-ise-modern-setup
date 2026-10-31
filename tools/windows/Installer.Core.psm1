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
Export-ModuleMember -Function Test-InstallCompleted,Move-PreviousRepairBackup,Get-NativeSetupCandidate
