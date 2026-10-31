"""Test the self-contained release payload without starting installers or changing settings."""
from pathlib import Path
import importlib.util
import subprocess
import tempfile

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
PAYLOAD=ROOT/'local/windows-single-build/Helper.ps1'
spec=importlib.util.spec_from_file_location('fixtures',HERE/'test_repair.py')
fixtures=importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)

def main():
    parent=ROOT/'local/repair-tests'
    parent.mkdir(parents=True,exist_ok=True)
    runner=parent/'run-single-tests.ps1'
    runner.write_text('''param($Payload,$Root,$Language,$Mode)
. $Payload -Language $Language -FunctionsOnly
Say 'Ready'
Say 'WebTalkDone'
Say 'EqualizerDone'
$r=Invoke-Repair -Mode $Mode -InstallRoot $Root -SkipEnvironment
if($r -ne 0){exit 1}
''',encoding='utf-8-sig')
    outputs={}
    for language in ['en']:
        with tempfile.TemporaryDirectory(prefix='single-helper-',dir=parent) as tmp:
            root=Path(tmp)/'path with spaces'/'ISE_DS'
            root.mkdir(parents=True)
            originals=fixtures.fixture(root)
            for mode in ['Check','Apply','Apply','Restore']:
                p=subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(runner),str(PAYLOAD),str(root),language,mode],capture_output=True,text=True,errors='replace')
                assert p.returncode==0,p.stdout+p.stderr
                assert all(s not in p.stdout.lower() for s in ['experimental','remains yours','no installer path','does not prove','0.5'])
                outputs[language]=p.stdout
                if mode=='Check': assert not (root/'.ise-modern-repair').exists()
                elif mode=='Apply':
                    for f in originals:
                        arch='nt64' if 'nt64' in f.parts else 'nt'
                        assert f.read_bytes()==(root/f'ISE/lib/{arch}/libPortabilityNOSH.dll').read_bytes()
            assert all(f.read_bytes()==data for f,data in originals.items())
    assert 'WebTalk closed' in outputs['en'] and 'Stalled Version Equalizer task closed' in outputs['en']
    content=(ROOT/'downloads/ISE-Helper.cmd').read_text(encoding='utf-8')
    assert 'set "ISE_HELPER_LANGUAGE=en"' in content
    assert content.split('#--ISE-POWERSHELL--\n',1)[1] == PAYLOAD.read_text(encoding='utf-8-sig')
    assert content.count('#--ISE-POWERSHELL--')==1
    assert 'Import-Module (Join-Path $PSScriptRoot' not in content
    assert 'Invoke-WebRequest' not in content
    assert 'download/file.php' not in content
    assert not (ROOT/'downloads/ISE-Windows-Repair.zip').exists()
    assert not (ROOT/'downloads/ISE-Helper-CN.cmd').exists()
    print('PASS: English check/apply/repeat/byte-exact restore; visible messages; standalone release matches tested payload; no legacy ZIP or Chinese release.')

if __name__=='__main__':main()
