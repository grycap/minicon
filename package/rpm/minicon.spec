%define version %(cat ../../src/version | awk -F'-' '{print $1}')
%define revision %(cat ../../src/version | awk -F'-' '{print $2}')

Summary:        MiniCon - Minimization of Container Filesystems
License:        Apache 2.0
Name:           minicon
Version:        %{version}
Release:        %{revision}
Group:          System Environment
URL:            https://github.com/grycap/minicon
Packager:       Carlos A. <caralla@upv.es>
Requires:       bash, jq, tar, coreutils, tar, rsync, file, strace, glibc-common, which
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

%description 
 **minicon** aims at reducing the footprint of the filesystem for arbitrary
 the container, just adding those files that are needed. That means that the
 other files in the original container are removed.
 **minidock** is a helper to use minicon for Docker containers.
 
%prep
%setup -q
%build

%install
mkdir -p $RPM_BUILD_ROOT/bin/
install -m 0755 bin/minicon $RPM_BUILD_ROOT/bin
install -m 0755 bin/minidock $RPM_BUILD_ROOT/bin
install -m 0755 bin/importcon $RPM_BUILD_ROOT/bin
install -m 0755 bin/mergecon $RPM_BUILD_ROOT/bin

%post

%postun

%files
%defattr(-,root,root,700)
/bin/minicon
/bin/minidock
/bin/importcon
/bin/mergecon