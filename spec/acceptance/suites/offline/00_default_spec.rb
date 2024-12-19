require 'spec_helper_acceptance'

describe 'Offline mode' do
  hosts.each do |host|
    context "on #{host}" do
      let(:vagrant_version) { '2.2.5' }
      let(:vagrant_rpm) { "https://releases.hashicorp.com/vagrant/#{vagrant_version}/vagrant_#{vagrant_version}_x86_64.rpm" }
      let(:virtualbox_repo) { 'http://download.virtualbox.org/virtualbox/rpm/el/virtualbox.repo' }
      let(:build_user) { 'build_user' }
      let(:build_user_cmd) { "runuser #{build_user} -l -c" }

      # Not sure if this is a QEMU thing with the image or something else
      it 'works around a CentOS curl bug with libvirt' do
        on(host, %(touch /etc/sysconfig/64bit_strstr_via_64bit_strstr_sse2_unaligned))
      end

      it 'adds the build user' do
        on(host, %(useradd -b /home -G wheel -m -c "Build User" -s /bin/bash -U #{build_user}))

        # Allow the build user to perform privileged operations
        on(host, %(echo 'Defaults:build_user !requiretty' >> /etc/sudoers))
      end

      it 'installs required packages' do
        host.install_package('epel-release')

        required_packages = [
          'augeas-devel',
          'autoconf',
          'automake',
          'bison',
          'createrepo',
          'curl',
          'dkms',
          'initscripts',
          'gcc',
          'gcc-c++',
          'genisoimage',
          'git',
          'glibc-devel',
          'glibc-headers',
          'gnupg2',
          'kernel-devel',
          'libffi-devel',
          'libicu-devel',
          'libtool',
          'libvirt',
          'libvirt-client',
          'libvirt-devel',
          'libxml2',
          'libxml2-devel',
          'libxslt',
          'libxslt-devel',
          'libyaml-devel',
          'make',
          'ntpdate',
          'openssl',
          'openssl-devel',
          'qemu',
          'readline-devel',
          'rpm-build',
          'rpm-sign',
          'rpmdevtools',
          'ruby-devel',
          'rubygems',
          'seabios',
          'sqlite-devel',
          'util-linux',
          'which',
        ]

        on(host, %(yum -y install #{required_packages.join(' ')}))
        on(host, %(yum -y update))
      end

      it 'removes limits from the system' do
        # Remove system limits
        on(host, %(rm -rf /etc/security/limits.d/*.conf))
      end

      it 'installs the latest VirtualBox' do
        on(host, %(curl "#{virtualbox_repo}" -o /etc/yum.repos.d/virtualbox.repo))
        on(host, 'yum -y install $(yum -y list | grep VirtualBox | sort | tail -1 | cut -f 1 -d " ")')
      end

      it 'installs the VirtualBox extension pack' do
        on(host,
'VERSION=$(VBoxManage --version | tail -1 | cut -f 1 -d "r") && curl -Lo ${TMPDIR}/Oracle_VM_VirtualBox_Extension_Pack-${VERSION}.vbox-extpack http://download.virtualbox.org/virtualbox/${VERSION}/Oracle_VM_VirtualBox_Extension_Pack-${VERSION}.vbox-extpack && yes | VBoxManage extpack install ${TMPDIR}/Oracle_VM_VirtualBox_Extension_Pack-${VERSION}.vbox-extpack && rm -rf ${TMPDIR}/Oracle_VM_VirtualBox_Extension_Pack-${VERSION}.vbox-extpack')
      end

      it 'adds the build user to the vboxusers group' do
        on(host, %(usermod -a -G vboxusers #{build_user}))
      end

      it 'reboots the system to finalize VirtualBox' do
        host.reboot
      end

      it 'installs RPM for the build user' do
        # Install RVM
        on(host,
%(#{build_user_cmd} "for i in {1..5}; do { gpg2 --keyserver hkp://pgp.mit.edu --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3; } && { gpg2 --keyserver hkp://pgp.mit.edu --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB; } && break || sleep 1; done"))
        on(host, %(#{build_user_cmd} "gpg2 --refresh-keys"))
        on(host,
%(#{build_user_cmd} "curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer -o rvm-installer && curl -sSL https://raw.githubusercontent.com/rvm/rvm/stable/binscripts/rvm-installer.asc -o rvm-installer.asc && gpg2 --verify rvm-installer.asc rvm-installer && bash rvm-installer"))
        on(host, %(#{build_user_cmd} "rvm install 2.4.4 --disable-binary"))
        on(host, %(#{build_user_cmd} "rvm use --default 2.4.4"))
        on(host, %(#{build_user_cmd} "rvm all do gem install bundler -v '~> 1.16' --no-document"))
      end

      it 'installs vagrant' do
        on(host, %(yum -y install #{vagrant_rpm}))
      end

      it 'preps for testing by downloading boxes for tests' do
        on(host, %(#{build_user_cmd} "vagrant box add --provider virtualbox centos/6"))
        on(host, %(#{build_user_cmd} "vagrant box add --provider virtualbox centos/7"))
      end

      it 'runs a simple nested virt test' do
        build_user_homedir = on(host, "readlink -f ~#{build_user}").output.strip
        vagrant_testdir = "#{build_user_homedir}/vagrant_test"

        vagrant_test_file = <<-EOM
Vagrant.configure("2") do |c|
  c.vm.define 'test' do |v|
    v.vm.hostname = 'centos7.test.net'
    v.vm.box = 'centos/7'
    v.vm.box_check_update = 'false'
  end
end
        EOM

        host.mkdir_p(vagrant_testdir)

        create_remote_file(host, "#{vagrant_testdir}/Vagrantfile", vagrant_test_file)

        on(host, %(chown -R #{build_user} #{vagrant_testdir}))

        on(host, %(#{build_user_cmd} "cd #{vagrant_testdir} && vagrant up"))
        on(host, %(#{build_user_cmd} "cd #{vagrant_testdir} && vagrant destroy -f"))
      end

      # We're testing a real module since that has the widest set of
      # repercussions for reaching out to the internet
      it 'downloads a module to test' do
        on(host, %(#{build_user_cmd} "git clone https://github.com/simp/pupmod-simp-at"))
      end

      it 'preps the module for building' do
        on(host, %(#{build_user_cmd} "cd pupmod-simp-at; bundle update"))
      end

      it 'runs a network-connected test' do
        on(host, %(#{build_user_cmd} "cd pupmod-simp-at; rake beaker:suites"))
      end

      it 'disables all internet network traffic via iptables' do
        on(host, %(iptables -I OUTPUT -d `ip route | awk '/default/ {print $3}'`/16 -j ACCEPT))
        on(host, 'iptables -A OUTPUT -j DROP')
      end

      xit 'runs a network-disconnected test' do
        on(host, %(#{build_user_cmd} "cd pupmod-simp-at; rake beaker:suites"))
      end
    end
  end
end
