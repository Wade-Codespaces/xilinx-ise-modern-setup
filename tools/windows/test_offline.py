"""Verify local patch generation against retained official DLLs and author ZIP.

Requires private evidence under local/; never downloads or runs a vendor DLL.
"""
from pathlib import Path
import json
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BACKUP = ROOT/'local/windows-verification/first-install/repair-backup'
PAYLOAD = ROOT/'local/windows-single-build/Helper.ps1'

def main():
    state = json.loads((BACKUP/'state.json').read_text(encoding='utf-8-sig'))
    with zipfile.ZipFile(ROOT/'local/repair-tests/czietz-original-hotfix.zip') as z:
        expected = {arch: z.read(arch+'/libPortability.dll') for arch in ['nt','nt64']}
    with tempfile.TemporaryDirectory(dir=ROOT/'local/repair-tests', prefix='offline-') as tmp:
        tmp = Path(tmp)
        runner = tmp/'test.ps1'
        runner.write_text('''param($Payload,$Root,$Dest,$Language,$Mode)
. $Payload -Language $Language -FunctionsOnly
New-LocalHotfix -InstallRoot $Root -Destination $Dest
if(-not(Test-Hotfix $Dest)){throw 'Generated hash mismatch'}
if($Mode -eq 'Repair'){
 foreach($step in @('Apply','Apply')){
  if((Invoke-Repair -Mode $step -InstallRoot $Root -HotfixRoot $Dest -SkipEnvironment) -ne 0){throw $step}
  New-LocalHotfix -InstallRoot $Root -Destination $Dest
 }
 if((Invoke-Repair -Mode Restore -InstallRoot $Root -SkipEnvironment) -ne 0){throw 'Restore'}
}
''', encoding='utf-8-sig')
        for language in ['zh','en']:
            root = tmp/language/'ISE_DS'
            originals = {}
            for entry in state['Files']:
                target = root/entry['Relative'].replace('\\','/')
                target.parent.mkdir(parents=True, exist_ok=True)
                originals[target] = (BACKUP/entry['Backup']).read_bytes()
                target.write_bytes(originals[target])
            (root/'settings64.bat').write_text('@echo off\n')
            dest = tmp/language/'generated'
            def run(mode):
                return subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(runner),str(PAYLOAD),str(root),str(dest),language,mode], capture_output=True,text=True,errors='replace')
            result = run('Repair')
            assert result.returncode == 0, result.stdout+result.stderr
            for arch in expected:
                assert (dest/arch/'libPortability.dll').read_bytes() == expected[arch]
            assert all(p.read_bytes() == data for p,data in originals.items())
            for arch, relative in [('nt','ISE/lib/nt/libPortability.dll'),('nt64','ISE/lib/nt64/libPortabilityNOSH.dll')]:
                target = root/relative
                original = target.read_bytes()
                damaged = bytearray(original); damaged[100] ^= 1
                target.write_bytes(damaged)
                result = run('Generate')
                assert result.returncode != 0, 'Unknown baseline accepted'
                assert target.read_bytes() == damaged, 'Baseline unexpectedly modified'
                target.write_bytes(original)
    print('PASS: both languages generate byte-identical author DLLs offline; all 13 files apply/repeat/restore; patched inputs accepted; either unknown baseline rejected without modifying input.')

if __name__ == '__main__':
    main()
