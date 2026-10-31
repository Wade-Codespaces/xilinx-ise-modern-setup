# ISE Installation Helper: Technical Notes

[简体中文](helper.md) | [English](helper.en.md) · [Back to the Windows guide](README.en.md)

This document describes the helper's components, operating mechanisms, file changes, and patch sources. For installation steps, see the [Windows guide](README.en.md).

## Components and runtime

`ISE-Helper.cmd` works with the official native Windows ISE 14.7 installer. It contains the startup entry point, installation monitoring logic, DLL patch rules, and backup logic. It uses the Windows command interpreter and Windows PowerShell, without Python or additional script modules.

The entry point requests administrator access, then runs monitoring and repair in the same window. The script and official package can be in different locations. The installer path is obtained from its running process, and the installation directory from related child processes of that installation.

## Installer detection and monitoring

The helper waits for a native installer process and checks its path, Xilinx signature, and package layout. Starting the helper midway through installation uses the same detection mechanism. If the relevant child processes have already exited near the end of installation, it may be unable to identify the installation directory.

WebTalk handling is limited to child processes of the detected installer. Version Equalizer handling additionally checks the execution stage, the `xilperl.exe` path, and the `fix_version.pl` command line. After 30 seconds without CPU, I/O, or log activity changes, it terminates that stalled task and records the stage as bypassed.

Handling Version Equalizer lets installation continue; it does not establish that System Generator integration with MATLAB works. The helper does not automatically associate MATLAB.

## Completion checks and file repair

After the installer exits, the helper checks its exit code, success markers in the current installation log, log timestamps, and key files. File repair starts only after these checks succeed and related ISE applications have closed.

The repair process reads official 32-bit and 64-bit DLLs, generates and verifies repair copies, backs up the original targets, then replaces each file and checks its SHA-256. Local verification of the full suite covered 13 DLL locations; actual targets depend on the installed components. The helper also sets the current user's `XILINX_VC_CHECK_NOOP` variable to `1` for the ISE startup check.

## Backups and logs

Original DLLs and recovery records are stored in `.ise-modern-repair/` under the installation directory. Records include relative file paths, hashes before and after replacement, and the previous startup check variable value. Repeated application preserves the original backups. Restore logic checks whether files have undergone additional changes.

Runtime logs and generated repair copies are stored under `%LOCALAPPDATA%\ISE-Modern-Setup\sessions\`, with a separate session directory for each run.

## Patch provenance and reproduction

The DLL fix comes from **czietz**, posted on **December 24, 2022** in the exxos forum thread *Xilinx Impact Suddenly Stopped Working*. The attachment is named `xilinx-ise-win10-hang-hotfix.zip`. The author explains that the patch makes network share enumeration take a failure path to avoid a hang involving WSL shares, and notes that loading files from network shares might be affected.

[Original explanation](https://www.exxosforum.co.uk/forum/viewtopic.php?t=6052#p95891) · [Original attachment](https://www.exxosforum.co.uk/forum/download/file.php?id=29188)

This project compared that attachment with official files from the local installation to extract fixed binary modification rules. The helper reproduces the patch on the user's computer: it checks the official DLL's SHA-256, applies the fixed modifications to a copy, then checks the generated file's SHA-256. Only output matching the verified original attachment is passed to the backup and replacement process. No DLL download is needed at runtime. An unrecognized official file version stops repair.

Credit for the patch method belongs to czietz. This project supplies rule extraction, local reproduction, file verification and backups, and installation automation. WebTalk and Version Equalizer monitoring are part of this project's helper logic, rather than features supplied by the DLL attachment.

The verified original attachment ZIP has SHA-256 `9CF48F4E08E54194CB01F6751FADF59C442F3E2B88BB93891B50087258C54703`. The two DLLs in that attachment, and the locally generated copies, have these hashes:

| File | SHA-256 |
| --- | --- |
| nt/libPortability.dll | `6B36659BDF3207271B33057E6C6E61E3B3D734AFFD6A7CFC80672B8B3A73B07B` |
| nt64/libPortability.dll | `F31D61BAE911A382DF552EE477B07F52729FC65B414F85617188591147BFA1E6` |

Local tests confirmed that generated files match the verified attachment byte for byte, and that replacement at 13 locations, repeated application, and restoration pass. User screenshots from November 1, 2026 further confirm that the helper handled WebTalk and Version Equalizer, followed by successful completion of the official installation. After the installer exited, the helper generated repair copies, replaced 13 DLLs, and configured the startup check variable. ISE Project Navigator then opened to its main window.

The download contains this project's script, without bundled third-party DLLs, ISE, licenses, or a virtual machine. The ISE installer is downloaded from AMD.
