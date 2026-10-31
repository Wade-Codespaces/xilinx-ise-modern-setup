# Packages the retained build, not ISE or a system filesystem.
Name:           ise-netatalk
Version:        3.1.7
Release:        2.iseol6
Summary:        Netatalk AFP server from the recorded ISE Oracle Linux 6.4 build
License:        GPLv2+
Group:          System Environment/Daemons
URL:            https://netatalk.io/
Source0:        netatalk-3.1.7.tar.bz2
Source1:        netatalk-runtime.tar.gz
Source2:        rebuild-from-source.sh
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch:      x86_64
Requires:       /sbin/ldconfig
Requires:       /sbin/service
Requires:       /sbin/chkconfig
Conflicts:      netatalk

%description
Precompiled Netatalk 3.1.7 collected from the user's Oracle Linux 6.4 x86_64
ISE VM build. Does not include Xilinx ISE, system libraries, account databases,
passwords or runtime AFP databases. The original corresponding source and
rebuild script accompany this package. Clean-image validation is required.
The service is NOT enabled or started by package installation.

%prep
%setup -q -n netatalk-3.1.7

%build
# Reuse the retained, compiled build without changing the donor installation.
# Source2 documents compilation with the recorded configuration arguments.

%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p "$RPM_BUILD_ROOT"
tar -xzf %{SOURCE1} -C "$RPM_BUILD_ROOT"
mkdir -p "$RPM_BUILD_ROOT/usr/share/doc/%{name}-%{version}"
mkdir -p "$RPM_BUILD_ROOT/usr/local/var/netatalk/CNID"
cp COPYING COPYRIGHT AUTHORS "$RPM_BUILD_ROOT/usr/share/doc/%{name}-%{version}/"
cp %{SOURCE2} "$RPM_BUILD_ROOT/usr/share/doc/%{name}-%{version}/"

%pre
if [ -e /usr/local/sbin/afpd ] && ! rpm -q ise-netatalk >/dev/null 2>&1; then
    echo 'An unmanaged Netatalk installation already exists. Refusing to overwrite it.' >&2
    exit 1
fi
if ! id ise >/dev/null 2>&1 || [ ! -d /home/ise ]; then
    echo 'This package requires the existing ise account and /home/ise directory.' >&2
    exit 1
fi

%post
/sbin/ldconfig

%preun
if [ "$1" = 0 ]; then
    /sbin/service netatalk stop >/dev/null 2>&1 || :
    /sbin/chkconfig --del netatalk >/dev/null 2>&1 || :
fi

%postun
/sbin/ldconfig

%clean
rm -rf "$RPM_BUILD_ROOT"

%files
%defattr(-,root,root,-)
/usr/local/sbin/afpd
/usr/local/sbin/netatalk
/usr/local/sbin/cnid_dbd
/usr/local/sbin/cnid_metad
/usr/local/lib/libatalk.so*
%dir /usr/local/lib/netatalk
/usr/local/lib/netatalk/*.so
%dir /usr/local/var/netatalk
%dir /usr/local/var/netatalk/CNID
%config(noreplace) /usr/local/etc/afp.conf
%config(noreplace) /usr/local/etc/extmap.conf
%config(noreplace) /etc/pam.d/netatalk
/etc/rc.d/init.d/netatalk
%doc /usr/share/doc/%{name}-%{version}

%changelog
* Sat Oct 31 2026 ISE Setup Guide contributors - 3.1.7-2.iseol6
- Create the server state directory on clean installations.
* Fri Oct 30 2026 ISE Setup Guide contributors - 3.1.7-1.iseol6
- Package the retained OL6.4 x86_64 build with explicit runtime files only.
