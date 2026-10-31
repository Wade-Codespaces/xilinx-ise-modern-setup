"""Build the self-contained English CMD helper from tested core code."""
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent

def function(name, filename, replacements, exits=True):
    body = (HERE / filename).read_text(encoding='utf-8-sig')
    body = re.sub(r'^Import-Module .*\n', '', body, flags=re.M)
    for before, after in replacements:
        if before not in body:
            raise ValueError(f'Missing build anchor: {before}')
        body = body.replace(before, after)
    if exits:
        body = re.sub(r'\bexit (\d+)\b', r'return \1', body)
    return f'function {name} {{\n{body}\n}}\n'

def build():
    common = ''
    for module in ['Installer.Core.psm1', 'WebTalk.Core.psm1']:
        common += re.sub(r'^Export-ModuleMember .*\n?', '', (HERE/module).read_text(encoding='utf-8'),flags=re.M) + '\n'
    repair = function('Invoke-Repair', 'Repair-ISE.ps1', [
        ("    Write-Host 'ISE Modern Setup repair 0.5 (experimental)'", ''),
        ("    Write-Host $(if ($networkFix) {'Using hash-pinned czietz network hotfix.'} else {'Using bundled NOSH baseline; no network hotfix.'})", ''),
        ('            Write-Host "$(if ($before -eq $sourceHash) {\'MATCH\'} else {\'PLAN \'}) $relative"', ''),
        ('        Write-Host "Check complete: $($plan.Count) file(s) differ from selected repair source. No changes made."', "        Say 'CheckDone' $plan.Count"),
        ("        Write-Host 'Differences do not prove a DLL is broken: an existing third-party patch may differ too.'", ''),
        ('            Write-Host "RESTORED $($f.Relative)"', "            Say 'Restored' $f.Relative"),
        ("        Write-Host 'Restore complete. Backup retained.'", "        Say 'RestoreDone'"),
        ("            Write-Host 'Already applied. Original backups preserved.'; exit 0", "            Say 'AlreadyDone'; exit 0"),
        ('        Write-Host "APPLIED $($f.Relative)"', "        Say 'FileDone' $f.Relative"),
        ("    if (-not $SkipEnvironment) { [Environment]::SetEnvironmentVariable('XILINX_VC_CHECK_NOOP','1','User') }", "    if (-not $SkipEnvironment) { [Environment]::SetEnvironmentVariable('XILINX_VC_CHECK_NOOP','1','User'); Say 'EnvironmentDone' }"),
        ("    Write-Host 'Repair applied. Reopen your terminal/ISE. Real application validation is still required.'", "    Say 'RepairDone' $plan.Count"),
        ('    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red', "    Say 'Error' $_.Exception.Message"),
        ("    Write-Host 'If a prepared journal exists, close Xilinx tools and run Restore. Do not delete backups.'", ''),
    ])
    monitor = function('Invoke-Monitor', 'Watch-ISE-WebTalk.ps1', [
        ('    Write-Status "Watching installer PID $SetupProcessId for up to $TimeoutSeconds seconds. Ctrl+C cancels only the watcher."', "    Say 'Monitoring'"),
        ('            Write-Status "Installer exited. WebTalk processes stopped: $stopped. This does not prove installation succeeded."\n            exit 0', "            Say 'InstallerClosed'\n            return [pscustomobject]@{ Root=$InstallRoot; WebTalk=$stopped; Equalizer=$equalizerHandled }"),
        ('                Write-Status "Detected installation root from installer child: $InstallRoot"', "                Say 'Root' $InstallRoot"),
        ('            Write-Status "STOPPED installation WebTalk PID $($match.ProcessId). Installer preserved."', "            Say 'WebTalkDone'"),
        ('                    Write-Status "Version Equalizer candidate PID $($candidate.ProcessId); observing $IdleSeconds seconds without CPU/I/O/log changes."', "                    Say 'EqualizerWait' $IdleSeconds"),
        ('                        Write-Status "STOPPED stalled Version Equalizer Perl PID $($candidate.ProcessId). System Generator configuration still requires validation. Installer preserved."', "                        Say 'EqualizerDone'"),
        ('    Write-Status "TIMEOUT: watcher stopped; installer preserved. WebTalk processes stopped: $stopped."\n    exit 2', "    throw (Text 'Timeout')"),
        ('    Write-Status "FAILED: $($_.Exception.Message)"\n    exit 1', '    throw'),
    ], exits=False)
    # No hidden subprocesses: the same console monitors and then repairs.
    hotfix = (HERE/'Install-ISE.ps1').read_text(encoding='utf-8')
    hotfix = hotfix[hotfix.index('function Test-Hotfix'):hotfix.index('\ntry {')]
    payload = (HERE/'Single-Helper.Main.ps1').read_text(encoding='utf-8-sig')
    marker = '# INSERT_CORE'
    payload = payload.replace(marker, common + hotfix + repair + monitor)
    generated = ROOT/'local/windows-single-build'
    generated.mkdir(parents=True, exist_ok=True)
    # Testable canonical payload; release contains no extra PS1/module files.
    (generated/'Helper.ps1').write_text(payload, encoding='utf-8-sig')
    output = ROOT/'downloads/ISE-Helper.cmd'
    wrapper = ('@echo off\r\nsetlocal DisableDelayedExpansion\r\n'
                       'set "ISE_HELPER_SELF=%~f0"\r\n'
                       'set "ISE_HELPER_LANGUAGE=en"\r\n'
                       'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "'
                       "$t=[IO.File]::ReadAllText($env:ISE_HELPER_SELF);$m='#'+'--ISE-POWERSHELL--';"
                       '& ([scriptblock]::Create($t.Substring($t.IndexOf($m)+$m.Length))) '
                       '-Language $env:ISE_HELPER_LANGUAGE -SelfPath $env:ISE_HELPER_SELF"\r\n'
                       'exit /b %errorlevel%\r\n#--ISE-POWERSHELL--\r\n')
    data = (wrapper + payload.replace('\n','\r\n')).encode('utf-8')
    output.write_bytes(data)
    print(f'Built {output.name}: one independent English script, no bundled DLLs.')

if __name__ == '__main__':
    build()
