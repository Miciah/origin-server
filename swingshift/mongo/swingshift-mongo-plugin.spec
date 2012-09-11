%global ruby_sitelib %(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")
%global gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%global gemname swingshift-mongo-plugin
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}

Summary:        SwingShift plugin for mongo auth service
Name:           rubygem-%{gemname}
Version:        0.8.6
Release:        1%{?dist}
Group:          Development/Languages
License:        ASL 2.0
URL:            http://openshift.redhat.com
Source0:        rubygem-%{gemname}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires:       ruby(abi) = 1.8
Requires:       rubygems
Requires:       rubygem(stickshift-common)
Requires:       rubygem(json)
Requires:       rubygem(mocha)
Requires:       stickshift-broker
Requires:  		selinux-policy-targeted
Requires:  		policycoreutils-python

BuildRequires:  ruby
BuildRequires:  rubygems
BuildArch:      noarch
Provides:       rubygem(%{gemname}) = %version

%package -n ruby-%{gemname}
Summary:        SwingShift plugin for mongo auth service
Requires:       rubygem(%{gemname}) = %version
Provides:       ruby(%{gemname}) = %version

%description
Provides a mongo auth service based plugin

%description -n ruby-%{gemname}
Provides a mongo auth service based plugin

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{gemdir}
mkdir -p %{buildroot}%{ruby_sitelib}
mkdir -p %{buildroot}%{_bindir}

# Build and install into the rubygem structure
gem build %{gemname}.gemspec
gem install --local --install-dir %{buildroot}%{gemdir} --force %{gemname}-%{version}.gem

# Move the gem binaries to the standard filesystem location
mv %{buildroot}%{gemdir}/bin/* %{buildroot}%{_bindir}
rm -rf %{buildroot}%{gemdir}/bin

# Symlink into the ruby site library directories
ln -s %{geminstdir}/lib/%{gemname} %{buildroot}%{ruby_sitelib}
ln -s %{geminstdir}/lib/%{gemname}.rb %{buildroot}%{ruby_sitelib}

mkdir -p %{buildroot}/etc/stickshift/plugins.d
cp conf/swingshift-mongo-plugin.conf %{buildroot}/etc/stickshift/plugins.d/swingshift-mongo-plugin.conf

mkdir -p %{buildroot}/var/www/stickshift/broker/config/initializers/
cp conf/swingshift-mongo-plugin.rb %{buildroot}/var/www/stickshift/broker/config/initializers/swingshift-mongo-plugin.rb
cp conf/swingshift-mongo-plugin.conf %{buildroot}/var/www/stickshift/broker/config/initializers/swingshift-mongo-plugin-defaults.conf

%clean
rm -rf %{buildroot}

%post
/usr/bin/openssl genrsa -out /var/www/stickshift/broker/config/server_priv.pem 2048
/usr/bin/openssl rsa    -in /var/www/stickshift/broker/config/server_priv.pem -pubout > /var/www/stickshift/broker/config/server_pub.pem

%files
%defattr(-,root,root,-)
%dir %{geminstdir}
%doc %{geminstdir}/Gemfile
%{gemdir}/doc/%{gemname}-%{version}
%{gemdir}/gems/%{gemname}-%{version}
%{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec
%{_bindir}/*
%config(noreplace) %{_sysconfdir}/stickshift/plugins.d/swingshift-mongo-plugin.conf
/var/www/stickshift/broker/config/initializers/swingshift-mongo-plugin.rb
/var/www/stickshift/broker/config/initializers/swingshift-mongo-plugin-defaults.conf

%files -n ruby-%{gemname}
%{ruby_sitelib}/%{gemname}
%{ruby_sitelib}/%{gemname}.rb

%changelog
* Mon Aug 20 2012 Brenton Leanhardt <bleanhar@redhat.com> 0.8.6-1
- gemspec refactorings based on Fedora packaging feedback (bleanhar@redhat.com)
- Providing a better error message for invalid broker iv/token
  (kraman@gmail.com)
- fix for cartridge-jenkins_build.feature cucumber test (abhgupta@redhat.com)
- Bug 836055 - Bypass authentication by making a direct request to broker with
  broker_auth_key (kraman@gmail.com)
- MCollective updates - Added mcollective-qpid plugin - Added mcollective-
  gearchanger plugin - Added mcollective agent and facter plugins - Added
  option to support ignoring node profile - Added systemu dependency for
  mcollective-client (kraman@gmail.com)
- Updated gem info for rails 3.0.13 (admiller@redhat.com)

* Wed May 30 2012 Krishna Raman <kraman@gmail.com> 0.8.5-1
- Fix for Bugz 825366, 825340. SELinux changes to allow access to
  user_action.log file. Logging authentication failures and user creation for
  OpenShift Origin (abhgupta@redhat.com)
- Raise auth exception when no user/password is provided by web browser. Bug
  815971 (kraman@gmail.com)
- Adding livecd build scripts Adding a text only minimal version of livecd
  Added ability to access livecd dns from outside VM (kraman@gmail.com)
- Merge pull request #19 from kraman/dev/kraman/bug/815971
  (dmcphers@redhat.com)
- Fix bug in mongo auth service where auth failure is returning nil instead of
  Exception (kraman@gmail.com)
- Adding a seperate message for errors returned by cartridge when trying to add
  them. Fixing CLIENT_RESULT error in node Removing tmp editor file
  (kraman@gmail.com)
- Added tests (kraman@gmail.com)
- BugZ# 817957. Adding rest api for creating a user in the mongo auth service.
  Rest API will be accessabel only from local host and will require login/pass
  of an existing user. (kraman@gmail.com)
- moving broker auth key and iv encoding/decoding both into the plugin
  (abhgupta@redhat.com)

* Thu Apr 26 2012 Krishna Raman <kraman@gmail.com> 0.8.4-1
- Added README for SwingShift-mongo plugin (rpenta@redhat.com)
- cleaning up spec files (dmcphers@redhat.com)
- decoding the broker auth key before returning from login in the auth plugin
  (abhgupta@redhat.com)

* Sat Apr 21 2012 Krishna Raman <kraman@gmail.com> 0.8.3-1
- new package built with tito
