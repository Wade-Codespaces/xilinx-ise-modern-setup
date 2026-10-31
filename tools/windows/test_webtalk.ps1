$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'WebTalk.Core.psm1') -Force
function Proc($Id, $Parent, $Name, $Seconds) {
    [pscustomobject]@{ ProcessId=[uint32]$Id; ParentProcessId=[uint32]$Parent; Name=$Name; CreationDate=([datetime]'2026-10-31T12:00:00').AddSeconds($Seconds) }
}
$born = [datetime]'2026-10-31T12:00:00'
$items = @(
    (Proc 100 1 'xsetup.exe' 0),
    (Proc 101 100 'installer-helper.exe' 1),
    (Proc 102 101 'xwebtalk.exe' 2),
    (Proc 103 100 'xwebtalk.exe' 3),
    (Proc 200 1 'xsetup.exe' 0),
    (Proc 201 200 'xwebtalk.exe' 2),
    (Proc 300 1 'xwebtalk.exe' 2),
    (Proc 400 401 'xwebtalk.exe' 2),
    (Proc 401 400 'loop.exe' 2),
    (Proc 500 100 'helper.exe' 10),
    (Proc 501 500 'xwebtalk.exe' 2)
)
$result = @(Get-InstallationWebTalk -Processes $items -SetupProcessId 100 -SetupCreationDate $born)
if (($result.ProcessId -join ',') -ne '102,103') { throw 'Incorrect descendant selection.' }
$result = @(Get-InstallationWebTalk -Processes $items -SetupProcessId 100 -SetupCreationDate $born.AddSeconds(1))
if ($result.Count) { throw 'Reused installer PID accepted.' }
$result = @(Get-InstallationWebTalk -Processes @($items | Where-Object ProcessId -ne 100) -SetupProcessId 100 -SetupCreationDate $born)
if ($result.Count) { throw 'Exited installer accepted.' }
Write-Host 'PASS: direct and indirect children; unrelated installations excluded; cyclic lineage excluded; parent PID reuse excluded; installer PID reuse/exit excluded. No real processes terminated.'
$installRoot = 'C:\Xilinx_ISE\14.7\ISE_DS'
$perl = Proc 600 101 'xilperl.exe' 3
$perl | Add-Member ExecutablePath "$installRoot\ISE\bin\nt64\xilperl.exe"
$perl | Add-Member CommandLine ('"' + $perl.ExecutablePath + '" "' + $installRoot + '\ISE\sysgen\util\fix_version.pl" args')
foreach ($name in @('KernelModeTime','UserModeTime','ReadTransferCount','WriteTransferCount')) { $perl | Add-Member $name 0 }
$snapshot = @($items) + @($perl)
$tail = @('INFO ::time:: Execute: Version Equalizer')
$found = @(Get-VersionEqualizerCandidate -Processes $snapshot -SetupProcessId 100 -SetupCreationDate $born -InstallRoot $installRoot -LogTail $tail)
if ($found.Count -ne 1 -or $found[0].ProcessId -ne 600) { throw 'Equalizer selection failed.' }
$wrongStage = @(Get-VersionEqualizerCandidate -Processes $snapshot -SetupProcessId 100 -SetupCreationDate $born -InstallRoot $installRoot -LogTail @($tail + 'INFO ::time:: Execute: Next task'))
if ($wrongStage.Count) { throw 'Unrelated installation stage accepted.' }
$originalCommand = $perl.CommandLine
$perl.CommandLine = $originalCommand.Replace('fix_version.pl','other.pl')
if (@(Get-VersionEqualizerCandidate -Processes $snapshot -SetupProcessId 100 -SetupCreationDate $born -InstallRoot $installRoot -LogTail $tail).Count) { throw 'Unrelated Perl script accepted.' }
$perl.CommandLine = $originalCommand
$perl.ExecutablePath = 'C:\Other\xilperl.exe'
if (@(Get-VersionEqualizerCandidate -Processes $snapshot -SetupProcessId 100 -SetupCreationDate $born -InstallRoot $installRoot -LogTail $tail).Count) { throw 'Wrong executable path accepted.' }
$token = Get-EqualizerActivityToken $perl '123|456'
$perl.ReadTransferCount = 1
if ((Get-EqualizerActivityToken $perl '123|456') -eq $token) { throw 'Activity not detected.' }
if ((Get-EqualizerActivityToken $perl '123|457') -eq (Get-EqualizerActivityToken $perl '123|456')) { throw 'Log change not detected.' }
Write-Host 'PASS: Equalizer requires exact stage, installation path, script and lineage; I/O and log changes reset inactivity evidence. No real processes terminated.'
foreach ($p in $snapshot) { if (-not $p.PSObject.Properties['ExecutablePath']) { $p | Add-Member ExecutablePath $null } }
$items[2].ExecutablePath='E:\Custom Install\ISE_DS\.xinstall\bin\nt64\xwebtalk.exe'
$items[4].ExecutablePath='D:\Unrelated\ISE_DS\ISE\bin\nt64\ise.exe'
$roots=@(Get-InstallationRoots $snapshot 100 $born)
if ($roots.Count -ne 1 -or $roots[0] -ne 'E:\Custom Install\ISE_DS') { throw 'Root discovery included unrelated process or failed custom path.' }
$perl.ExecutablePath='C:\Another\ISE_DS\ISE\bin\nt64\xilperl.exe'
if (@(Get-InstallationRoots $snapshot 100 $born).Count -ne 2) { throw 'Conflicting roots not surfaced.' }
Write-Host 'PASS: installation root discovery supports custom paths and excludes unrelated process trees; conflicting roots surface for refusal.'
