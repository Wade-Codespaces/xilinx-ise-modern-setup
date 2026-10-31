# Netatalk offline disc

[简体中文](netatalk-disc.md) | [English](netatalk-disc.en.md) · [Back to the guide](README.en.md)

This document explains the disc contents and configuration used by the [Mac guide](README.en.md#7-install-netatalk-file-sharing).

## Purpose and supported environment

`ISE_NETATALK_3.1.7.iso` is an approximately **6.8 MB** offline installation disc for **Oracle Linux 6.4 x86_64** in the official ISE VM, using UTM **Shared Network**. It installs a precompiled RPM; the base image already contains its runtime dependencies.

[Download the disc](../../downloads/ISE_NETATALK_3.1.7.iso) · [SHA-256](../../downloads/ISE_NETATALK_3.1.7.iso.sha256)

## Disc contents

```text
ISE_NETATALK/
├── install.desktop       Desktop installer entry
├── install.sh            Readable installation script
├── readme.txt            Instructions and references
├── sha256sums            File checksums
├── packages/
│   └── netatalk.rpm      Precompiled runtime package
├── licenses/
│   ├── authors.txt       Upstream authors
│   ├── copying.txt       GPL license
│   └── copyright.txt     Copyright and permission notices
└── source/
    ├── netatalk.rpm      Corresponding source RPM
    ├── upstream.tbz      Original Netatalk 3.1.7 source
    ├── runtime.tgz       Runtime files used for packaging
    ├── netatalk.spec     RPM specification
    ├── configure.txt     Original configure arguments
    ├── comparison.txt    Source comparison record
    ├── prepare.py        Runtime packaging tool
    └── rebuild.sh        Source rebuild script
```

The desktop entry runs `install.sh`, which installs `packages/netatalk.rpm`. The `source/` directory supports inspection and rebuilding. Users do not need Python or a compiler to install the package. The disc contains no ISE software, complete system image, or certificate-update package.

## What the installer does

1. Shows the shared directory, network scope, and automatic-start settings, then waits for confirmation.
2. Obtains administrator privileges and checks the system version, architecture, account, and file checksums.
3. Checks that the Shared Network gateway is `192.168.64.1` and identifies the active network interface.
4. Checks RPM dependencies, installs Netatalk 3.1.7, and writes the share configuration and service script.
5. Enables startup at boot, configures firewall access, and starts the service.
6. Displays service status and the `afp://…` address for Finder.

The package provides the AFP server, DHX2 authentication module, and CNID database services. It creates `/usr/local/var/netatalk/CNID`; the VM generates its own service state when Netatalk runs.

## Shared directory

The share uses the existing `ise` account and its current password. Its name is `ise share`, mapped to `/home/ise`. `/usr/local/etc/afp.conf` contains:

```ini
[Global]
uam list = uams_dhx2.so

[ise share]
path = /home/ise
valid users = ise
```

## Firewall and startup

When iptables is running, the installer inserts the rule below at the start of INPUT, unless the same rule already exists. It obtains the interface from the default route; `eth1` is an example:

```sh
iptables -I INPUT 1 -i eth1 -s 192.168.64.1/32 \
  -p tcp --dport 548 -m state --state NEW -j ACCEPT
service iptables save
```

This permits AFP on TCP 548 from the Mac host at `192.168.64.1` through the active interface and saves the rule in `/etc/sysconfig/iptables`.

The service is registered and started with:

```sh
chkconfig --add netatalk
chkconfig netatalk on
service netatalk start
```

## Source, build tools, and validation

Inspect the [installer](../../tools/netatalk/install.sh), [RPM specification](../../tools/netatalk/ise-netatalk.spec), and [disc builder](../../tools/netatalk/build-disc.py). The source RPM contains the original source, retained build artifacts, and rebuild script. See the [build instructions](../../tools/netatalk/README.md).

RPM installation, AFP authentication, bidirectional text-file transfers, service startup after reboot, and remounting were verified on a fresh official image. The final disc passed checksums for all 15 files and script syntax checks. Installation through the desktop entry and connection from Finder were also completed; see the [installation screenshots](README.en.md#install-from-the-disc).
