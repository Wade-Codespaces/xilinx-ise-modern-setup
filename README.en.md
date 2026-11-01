# Xilinx ISE 14.7 Modern Setup

[简体中文](README.md) | [English](README.en.md)

A step-by-step Xilinx ISE 14.7 setup guide for **Windows 11** and **Apple Silicon Macs**, with screenshots and an offline file-sharing installer.

## Why this guide exists

Some courses and projects using older devices still require ISE. The official VM approach for modern Windows runs an additional Linux system and consumes extra resources. The Windows guide uses native installation with compatibility fixes.

ISE has no native macOS version, and Apple Silicon's ARM architecture cannot directly run the official x86_64 system. This guide uses UTM to emulate the official VM and an offline Netatalk disc to enable file sharing in Finder. It covers downloading and converting the disk, booting the desktop, and accessing files from macOS.

## Choose your platform

| Platform | Approach |
| --- | --- |
| [Apple Silicon Mac](docs/macos/README.en.md) | Official ISE VM emulated in UTM, with AFP file sharing |
| [Windows 11](docs/windows/README.en.md) | Native installation and compatibility fixes |

## References and acknowledgments

- Kevin Patterson: [Running the Xilinx ISE on an M1 MacBook Pro](https://www.youtube.com/watch?v=h4-FIYJfRUE), 2022. The main video reference for the Mac workflow.
- Dmitry Dovidenko: [Netatalk 3.1.7 on CentOS 6.6 x86_64](https://dovidenko.com/2015/359/howto-compiling-installing-configuring-netatalk-3-1-7-centos-6-6-x86_64-storage-time-machine.html), 2015. Reference for compiling and configuring Netatalk.
- czietz: [Xilinx Impact Suddenly Stopped Working](https://www.exxosforum.co.uk/forum/viewtopic.php?t=6052#p95891), December 24, 2022. Source of the Windows DLL fix that adjusts network share enumeration to address related startup hangs. This project's Windows helper reproduces the patch locally, verifies the files, and backs up the originals.

This guide adapts those workflows with compressed disk conversion, the existing ise account, and an offline installation disc. It also covers UTM disk compression and Finder access. See [NOTICE](NOTICE.md) for third-party sources and licensing.
