#!/bin/bash
set -euo pipefail
export LC_ALL=C

disc_dir=$(cd "$(dirname "$0")" && pwd)
package="$disc_dir/packages/netatalk.rpm"

fail() {
    printf '\nInstallation stopped: %s\n' "$1" >&2
    if [ -t 0 ]; then read -r -p 'Press Enter to close. ' response; fi
    exit 1
}

trap 'fail "See the command output above for details."' ERR

if [ "${1:-}" != '--apply' ]; then
    printf 'ISE Netatalk 3.1.7 Offline Installer\n\n'
    printf 'Shared folder: /home/ise\nAccount: ise (existing password)\n'
    printf 'Network: UTM Shared Network\nAFP access: this Mac only (192.168.64.1, TCP 548)\n'
    printf 'Netatalk will start now and at boot.\n\n'
    read -r -p 'Press Enter to install, or Ctrl+C to cancel. ' response
    sudo /bin/bash "$0" --apply
    read -r -p 'Press Enter to close. ' response
    exit 0
fi

[ "$EUID" -eq 0 ] || fail 'Administrator permission is required.'
[ "$(uname -m)" = x86_64 ] || fail 'This package requires x86_64.'
grep -q 'Oracle Linux Server release 6.4' /etc/oracle-release || fail 'Use the official Oracle Linux 6.4 ISE VM.'
id ise >/dev/null
[ -d /home/ise ] || fail '/home/ise is missing.'
[ -f "$package" ] || fail 'The RPM is missing from the disc.'
cd "$disc_dir"
sha256sum -c sha256sums

route_line=$(/sbin/ip -4 route show default | head -1)
gateway=$(printf '%s\n' "$route_line" | awk '{for (field_index=1;field_index<=NF;field_index++) if ($field_index=="via") print $(field_index+1)}')
interface=$(printf '%s\n' "$route_line" | awk '{for (field_index=1;field_index<=NF;field_index++) if ($field_index=="dev") print $(field_index+1)}')
[ "$gateway" = 192.168.64.1 ] || fail 'Select Shared Network in UTM, then retry.'
[[ "$interface" =~ ^[a-zA-Z0-9_.:-]+$ ]] || fail 'An active network interface is required.'

if [ "$(rpm -q ise-netatalk 2>/dev/null || true)" != 'ise-netatalk-3.1.7-2.iseol6.x86_64' ]; then
    rpm -Uvh --test "$package"
    rpm -Uvh "$package"
fi
/sbin/chkconfig --add netatalk
/sbin/chkconfig netatalk on

if /sbin/service iptables status >/dev/null 2>&1; then
    if ! /sbin/iptables -S INPUT | grep -F -- "-s $gateway/32 -i $interface -p tcp -m tcp --dport 548 -m state --state NEW -j ACCEPT" >/dev/null; then
        /sbin/iptables -I INPUT 1 -i "$interface" -s "$gateway/32" -p tcp --dport 548 -m state --state NEW -j ACCEPT
    fi
    /sbin/service iptables save
fi

/sbin/service netatalk start
/sbin/service netatalk status
address=$(/sbin/ip -4 -o addr show dev "$interface" | awk '{split($4,parts,"/"); print parts[1]; exit}')
printf '\nInstallation complete.\nFinder > Go > Connect to Server:\nafp://%s\n\nUser: ise\nShare: ise share\n' "$address"
