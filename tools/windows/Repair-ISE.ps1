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
    Write-Host 'ISE Modern Setup repair 0.5 (experimental)'
    $networkFix = -not [string]::IsNullOrWhiteSpace($HotfixRoot)
    Write-Host $(if ($networkFix) {'Using hash-pinned czietz network hotfix.'} else {'Using bundled NOSH baseline; no network hotfix.'})
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
            Write-Host "RESTORED $($f.Relative)"
        }
        if ($state.Environment.Enabled) {
            [Environment]::SetEnvironmentVariable('XILINX_VC_CHECK_NOOP',$state.Environment.Before,'User')
        }
        $state.Status = 'Restored'
        Save-State $state
        Write-Host 'Restore complete. Backup retained.'
        exit 0
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
            Write-Host "$(if ($before -eq $sourceHash) {'MATCH'} else {'PLAN '}) $relative"
            if ($before -ne $sourceHash) {
                $plan += [pscustomobject]@{ Relative=$relative; Source=$source; Before=$before; After=$sourceHash; Backup="$($plan.Count).bin" }
            }
        }
    }
    if ($Mode -eq 'Check') {
        Write-Host "Check complete: $($plan.Count) file(s) differ from selected repair source. No changes made."
        Write-Host 'Differences do not prove a DLL is broken: an existing third-party patch may differ too.'
        exit 0
    }
    if (Test-Path -LiteralPath $statePath) {
        $old = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if ($old.Status -eq 'Applied' -and $old.Root -eq $root -and $plan.Count -eq 0 -and
            ($SkipEnvironment -or [Environment]::GetEnvironmentVariable('XILINX_VC_CHECK_NOOP','User') -eq '1')) {
            Write-Host 'Already applied. Original backups preserved.'; exit 0
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
        Write-Host "APPLIED $($f.Relative)"
    }
    if (-not $SkipEnvironment) { [Environment]::SetEnvironmentVariable('XILINX_VC_CHECK_NOOP','1','User') }
    $state.Status = 'Applied'; Save-State $state
    Write-Host 'Repair applied. Reopen your terminal/ISE. Real application validation is still required.'
    exit 0
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'If a prepared journal exists, close Xilinx tools and run Restore. Do not delete backups.'
    exit 1
}
