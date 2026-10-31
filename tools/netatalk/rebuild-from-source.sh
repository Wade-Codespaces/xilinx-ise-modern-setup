#!/bin/sh
# Run in a compatible OL6 x86_64 build environment with build dependencies.
# Extract the accompanying original source archive before invoking this script
# from the resulting netatalk-3.1.7 directory. This stages; it does not install.
set -eu
if [ "$(id -u)" = 0 ]; then
    echo 'Run this build and staging script as an ordinary user, not root.' >&2
    exit 1
fi
: "${1:?Usage: sh rebuild-from-source.sh /absolute/empty/staging-directory}"
case "$1" in /*) ;; *) echo 'Staging path must be absolute.' >&2; exit 1;; esac
if [ -e "$1" ]; then echo 'Use a new staging directory.' >&2; exit 1; fi
./configure --with-init-style=redhat-sysv --without-tdb --with-cracklib \
    --enable-krbV-uam --with-pam-confdir=/etc/pam.d \
    --with-dbus-sysconf-dir=/etc/dbus-1/system.d
make
mkdir -p "$1"
# Run unprivileged. Upstream attempts ldconfig after staging; its failure is
# ignored upstream and cannot update the system cache without root privileges.
make install DESTDIR="$1"
