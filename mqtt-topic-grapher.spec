Name:      mqtt-topic-grapher
Summary:   mqtt-topic-grapher
Version:   0.08
Release:   1%{?dist}
License:   perl
Group:     System Environment/Daemons
Source0:   %{name}-%{version}.tar.gz
Requires:  perl(DateTime)
Requires:  perl(Net::MQTT::Simple)
Requires:  perl(Time::HiRes::Sleep::Until)
Requires:  perl(RRD::Simple)
Requires:  perl(Path::Class)
Requires:  perl(CGI)
Requires:  perl(JSON::XS)
Requires:  perl(List::MoreUtils)
Requires:  systemd
Requires:  httpd-on
BuildRequires: /usr/bin/rrdtool
BuildArch: noarch

%description 
mqtt-topic-grapher

%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p                    $RPM_BUILD_ROOT/%{_datadir}/%{name}/html/images/
cp %{name}.pl               $RPM_BUILD_ROOT/%{_datadir}/%{name}/
mkdir -p                    $RPM_BUILD_ROOT/%{_unitdir}/
cp %{name}.service          $RPM_BUILD_ROOT/%{_unitdir}/
mkdir -p                    $RPM_BUILD_ROOT/%{_localstatedir}/%name/
mkdir -p                    $RPM_BUILD_ROOT/%{_sysconfdir}/httpd/conf.d
cp %{name}.conf             $RPM_BUILD_ROOT/%{_sysconfdir}/httpd/conf.d/

%post
systemctl daemon-reload
systemctl enable  %{name}.service
systemctl restart %{name}.service
systemctl reload  httpd.service

%files
%dir %attr(0755,root,root) %{_datadir}/%{name}
%dir %attr(0755,root,root) %{_datadir}/%{name}/html
%dir %attr(0755,root,root) %{_datadir}/%{name}/html/images
%attr(0755,root,root) %{_datadir}/%{name}/%{name}.pl
%attr(0644,root,root) %{_unitdir}/%{name}.service
%dir %attr(0755,root,root) %{_localstatedir}/%name
%attr(0644,root,root) %{_sysconfdir}/httpd/conf.d/%{name}.conf

%clean
rm -rf $RPM_BUILD_ROOT

%changelog
