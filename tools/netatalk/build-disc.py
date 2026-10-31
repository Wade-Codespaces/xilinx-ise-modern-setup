#!/usr/bin/env python3
"""Assemble the local Netatalk installation disc and its source materials."""
import argparse
import hashlib
import shutil
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("materials", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
materials = args.materials.resolve()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
stage = output / "disc"
required = (
    "packages/netatalk.rpm", "source/netatalk.rpm", "source/upstream.tbz",
    "source/runtime.tgz", "source/configure.txt", "source/comparison.txt",
    "licenses/copying.txt", "licenses/copyright.txt", "licenses/authors.txt",
)
for relative in required:
    if not (materials / relative).is_file():
        parser.error(f"Missing disc material: {relative}")
shutil.copytree(materials, stage)
tool_dir = Path(__file__).resolve().parent
for name, destination in (
    ("install.sh", "install.sh"),
    ("Install.desktop", "install.desktop"),
    ("DISC-README.txt", "readme.txt"),
):
    shutil.copyfile(tool_dir / name, stage / destination)
(stage / "install.sh").chmod(0o755)
(stage / "install.desktop").chmod(0o755)
for name, destination in (("ise-netatalk.spec", "netatalk.spec"), ("rebuild-from-source.sh", "rebuild.sh"), ("prepare-rpm-inputs.py", "prepare.py")):
    shutil.copyfile(tool_dir / name, stage / "source" / destination)
checksum_lines = []
for path in sorted(stage.rglob("*")):
    if path.is_file() and path.name != "sha256sums":
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        checksum_lines.append(f"{digest}  {path.relative_to(stage)}\n")
(stage / "sha256sums").write_text("".join(checksum_lines))
iso = output / "ISE_NETATALK_3.1.7.iso"
subprocess.run([
    "hdiutil", "makehybrid", "-iso", "-joliet",
    "-iso-volume-name", "ISE_NETATALK", "-joliet-volume-name", "ISE_NETATALK",
    "-o", str(iso), str(stage),
], check=True)
digest = hashlib.sha256(iso.read_bytes()).hexdigest()
(output / "ISE_NETATALK_3.1.7.iso.sha256").write_text(f"{digest}  {iso.name}\n")
print(f"{iso}\n{iso.stat().st_size} bytes\nSHA256 {digest}")
