"""Isolated file-operation tests; never writes persistent environment variables."""
from pathlib import Path
import os
import struct
import subprocess
import tempfile

SCRIPT = Path(__file__).with_name('Repair-ISE.ps1')

def pe(machine, marker):
    data = bytearray(256)
    struct.pack_into('<H', data, 0, 0x5A4D)
    struct.pack_into('<I', data, 0x3c, 128)
    struct.pack_into('<IH', data, 128, 0x4550, machine)
    data[200:200 + len(marker)] = marker
    return bytes(data)

def fixture(root):
    originals = {}
    (root / 'settings64.bat').write_text('@echo off\n')
    for arch, machine in [('nt', 0x14c), ('nt64', 0x8664)]:
        for folder in [f'ISE/lib/{arch}', f'common/lib/{arch}', f'.xinstall/bin/{arch}']:
            dest = root / folder
            dest.mkdir(parents=True)
            file = dest / 'libPortability.dll'
            file.write_bytes(pe(machine, b'original'))
            originals[file] = file.read_bytes()
        (root / f'ISE/lib/{arch}/libPortabilityNOSH.dll').write_bytes(pe(machine, b'nosh'))
    return originals

def run(root, mode, success=True, hotfix=None):
    result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(SCRIPT),
                             '-InstallRoot', str(root), '-Mode', mode, '-SkipEnvironment'] +
                            (['-HotfixRoot', str(hotfix)] if hotfix else []),
                            capture_output=True, text=True, errors='replace')
    assert (result.returncode == 0) == success, result.stdout + result.stderr
    return result.stdout

def main():
    with tempfile.TemporaryDirectory(prefix='ise-repair-test-') as tmp:
        root = Path(tmp) / 'custom drive space' / 'ISE_DS'
        root.mkdir(parents=True)
        originals = fixture(root)
        run(root, 'Check')
        assert not (root / '.ise-modern-repair').exists()
        run(root, 'Apply')
        for file in originals:
            arch = 'nt64' if 'nt64' in file.parts else 'nt'
            assert file.read_bytes() == (root / f'ISE/lib/{arch}/libPortabilityNOSH.dll').read_bytes()
        journal = root / '.ise-modern-repair/state.json'
        before = journal.read_bytes()
        run(root, 'Apply')
        assert journal.read_bytes() == before
        changed = next(iter(originals))
        patched = changed.read_bytes()
        changed.write_bytes(pe(0x14c, b'other update'))
        run(root, 'Restore', False)
        assert changed.read_bytes() != patched
        changed.write_bytes(patched)
        run(root, 'Restore')
        assert all(file.read_bytes() == data for file, data in originals.items())
        run(root, 'Restore')
        print('PASS: read-only check, paths with spaces, both architectures, six replacements, repeat apply, conflict refusal, byte-exact restore, repeat restore')
    with tempfile.TemporaryDirectory(prefix='ise-repair-test-') as tmp:
        root = Path(tmp)
        originals = fixture(root)
        (root / 'ISE/lib/nt64/libPortabilityNOSH.dll').write_bytes(pe(0x14c, b'wrong architecture'))
        run(root, 'Apply', False)
        assert all(file.read_bytes() == data for file, data in originals.items())
        assert not (root / '.ise-modern-repair').exists()
        print('PASS: wrong source architecture refuses before backup or mutation')
    with tempfile.TemporaryDirectory(prefix='ise-repair-test-') as tmp:
        root = Path(tmp)
        originals = fixture(root)
        run(root, 'Apply')
        patched = {file: file.read_bytes() for file in originals}
        (root / '.ise-modern-repair/0.bin').write_bytes(b'corrupted backup')
        run(root, 'Restore', False)
        assert all(file.read_bytes() == data for file, data in patched.items())
        print('PASS: corrupted backup blocks restoration before any DLL changes')
    hotfix = os.environ.get('ISE_HOTFIX_TEST_ROOT')
    if hotfix:
        with tempfile.TemporaryDirectory(prefix='ise-repair-test-') as tmp:
            root = Path(tmp)
            originals = fixture(root)
            for arch in ['nt', 'nt64']:
                f = root / f'ISE/lib/{arch}/libPortabilityNOSH.dll'
                originals[f] = f.read_bytes()
            run(root, 'Check', hotfix=hotfix)
            run(root, 'Apply', hotfix=hotfix)
            for file in originals:
                arch = 'nt64' if 'nt64' in file.parts else 'nt'
                assert file.read_bytes() == (Path(hotfix) / arch / 'libPortability.dll').read_bytes()
            run(root, 'Apply', hotfix=hotfix)
            run(root, 'Restore')
            assert all(f.read_bytes() == data for f, data in originals.items())
            print('PASS: hash-pinned original-author hotfix, eight targets including NOSH, repeat apply, byte-exact restore; DLLs copied only, never loaded')
        with tempfile.TemporaryDirectory(prefix='ise-repair-test-') as tmp:
            root = Path(tmp)
            originals = fixture(root)
            run(root, 'Apply', success=False, hotfix=root / 'ISE/lib')
            assert all(f.read_bytes() == data for f, data in originals.items())
            assert not (root / '.ise-modern-repair').exists()
            print('PASS: unrecognized hotfix hashes rejected without modification')

if __name__ == '__main__':
    main()
