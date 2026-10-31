#!/bin/sh
# Run inside the ISE Linux VM. Optional argument: retained Netatalk source directory.
# Only stdout is written; no packages, configuration or services are changed.
set -eu

if [ "$(uname -s)" != Linux ]; then
    echo 'Please run this script inside the ISE Linux VM, not on macOS.' >&2
    exit 1
fi

echo '=== System compatibility ==='
uname -m
for release_file in /etc/oracle-release /etc/redhat-release; do
    if [ -f "$release_file" ]; then cat "$release_file"; fi
done
getconf GNU_LIBC_VERSION 2>/dev/null || true

echo '=== Netatalk version and compiled paths ==='
afpd_path=$(command -v afpd || true)
if [ -z "$afpd_path" ]; then
    for candidate in /usr/local/sbin/afpd /usr/sbin/afpd; do
        if [ -x "$candidate" ]; then afpd_path=$candidate; break; fi
    done
fi
if [ -n "$afpd_path" ]; then
    "$afpd_path" -V 2>&1
else
    echo 'afpd not found in PATH or standard locations.'
fi

echo '=== Installed executable and module dependencies ==='
for install_prefix in /usr/local /usr; do
    for executable in "$install_prefix/sbin/afpd" "$install_prefix/sbin/netatalk" "$install_prefix/sbin/cnid_metad" "$install_prefix/sbin/cnid_dbd"; do
        if [ -f "$executable" ]; then
            printf '\n%s\n' "$executable"
            file "$executable"
            # Only inspect binaries already installed in this trusted VM.
            ldd "$executable" 2>&1 || true
        fi
    done
    for module in "$install_prefix"/lib/netatalk/*.so "$install_prefix"/lib64/netatalk/*.so; do
        if [ -f "$module" ]; then
            printf '\n%s\n' "$module"
            ldd "$module" 2>&1 || true
        fi
    done
done

echo '=== Service script availability (contents not collected) ==='
for service_file in /etc/init.d/netatalk /etc/rc.d/init.d/netatalk; do
    if [ -f "$service_file" ]; then printf '%s\n' "$service_file"; fi
done

echo '=== Optional retained build ==='
if [ "$#" -gt 0 ]; then
    if [ ! -d "$1" ]; then echo 'Source directory not found.' >&2; exit 1; fi
    (
        cd "$1"
        if [ -f config.status ]; then
            # Autoconf --config prints the recorded configure arguments only.
            sh ./config.status --config
        else
            echo 'No config.status found; original configure arguments unavailable.'
        fi
        for source_file in COPYING INSTALL Makefile; do
            if [ -f "$source_file" ]; then printf 'Present: %s\n' "$source_file"; fi
        done
    )
else
    echo 'No source directory supplied. Retain the original source archive and build tree.'
fi

echo '=== End ==='
echo 'No passwords, account databases, AFP file contents or personal files were collected.'
echo 'Review output for local paths before sharing it publicly.'
