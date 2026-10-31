#!/usr/bin/env python3
"""Prepare an explicit runtime payload from the donor's DESTDIR export."""
import argparse
import hashlib
import json
import shutil
import tarfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("donor", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
if args.output.exists():
    parser.error("Output already exists; use a new output directory")
payload = args.donor / "payload"
runtime = args.output / "runtime"
runtime.mkdir(parents=True)
selected = [
    *[payload / "usr/local/sbin" / name for name in ("afpd", "netatalk", "cnid_dbd", "cnid_metad")],
    *sorted((payload / "usr/local/lib").glob("libatalk.so*")),
    *sorted((payload / "usr/local/lib/netatalk").glob("*.so")),
    payload / "usr/local/etc/extmap.conf",
    payload / "etc/pam.d/netatalk",
    payload / "etc/rc.d/init.d/netatalk",
]
manifest = []
for source in selected:
    relative = source.relative_to(payload)
    target = runtime / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        link = source.readlink()
        if link.is_absolute() or ".." in link.parts:
            raise ValueError(f"Unexpected symlink: {relative}")
        target.symlink_to(link)
        manifest.append({"path": str(relative), "symlink": str(link)})
    else:
        shutil.copyfile(source, target)
        # Runtime executables and ELF modules require no setuid/setgid bits.
        target.chmod(0o755 if source.stat().st_mode & 0o111 else 0o644)
        manifest.append({"path": str(relative), "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
config = runtime / "usr/local/etc/afp.conf"
config.write_text(
    "# ISE Setup Guide: existing ise account; no password is included.\n"
    "[Global]\n"
    "uam list = uams_dhx2.so\n\n"
    "[ise share]\n"
    "path = /home/ise\n"
    "valid users = ise\n", encoding="utf-8")
config.chmod(0o644)
manifest.append({"path": "usr/local/etc/afp.conf", "sha256": hashlib.sha256(config.read_bytes()).hexdigest()})
with tarfile.open(args.output / "netatalk-runtime.tar.gz", "w:gz") as archive:
    for path in sorted(runtime.rglob("*")):
        archive.add(path, arcname=str(path.relative_to(runtime)), recursive=False)
script_dir = Path(__file__).resolve().parent
for name in ("ise-netatalk.spec", "rebuild-from-source.sh"):
    shutil.copyfile(script_dir / name, args.output / name)
shutil.copyfile(args.donor / "source/netatalk-3.1.7.tar.bz2", args.output / "netatalk-3.1.7.tar.bz2")
(args.output / "payload-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Prepared {len(manifest)} runtime files/symlinks; no system libraries or AFP state included.")
