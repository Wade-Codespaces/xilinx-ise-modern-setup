ISE Netatalk 3.1.7 Offline Installation Disc
Oracle Linux 6.4 x86_64 / official ISE 14.7 VM

1. Add a removable IDE CD/DVD drive in UTM and select this ISO.
2. Set the network mode to Shared Network, then start the VM.
3. Open the ISE_NETATALK disc in the Linux file manager.
4. Open install.desktop. The installer opens in a terminal.
5. Press Enter to install. If prompted, enter the ise account password.
6. Use the displayed afp:// address in Finder (Command+K).
   User: ise. Official default password: xilinx. Share: ise share.

If the desktop launcher is unavailable, open a Linux terminal and run:
bash /media/ISE_NETATALK/install.sh
The file manager shows the mounted disc path if it differs.

The installer installs the RPM, enables Netatalk at boot and permits
TCP 548 from the Mac host 192.168.64.1 on the active Shared Network
interface. It preserves the existing account and password.

Packages: packages/ (runtime RPM)
Corresponding source: source/ (source RPM, original source, build inputs)
Licenses and author information: licenses/
Checksums: sha256sums

The source RPM contains the original build filenames and inputs.
Additional copies use short disc filenames for older Linux CD support:
upstream.tbz = netatalk-3.1.7.tar.bz2
runtime.tgz = netatalk-runtime.tar.gz
rebuild.sh = rebuild-from-source.sh

References:
Kevin Patterson, Running the Xilinx ISE on an M1 MacBook Pro (2022)
https://www.youtube.com/watch?v=h4-FIYJfRUE
Dmitry Dovidenko, Netatalk 3.1.7 on CentOS 6.6 x86_64 (2015)
https://dovidenko.com/2015/359/howto-compiling-installing-configuring-netatalk-3-1-7-centos-6-6-x86_64-storage-time-machine.html

This disc contains the independently packaged Netatalk service.
Netatalk is distributed under the included upstream license terms.
