require 'spec_helper_acceptance'

hosts.each do |host|
  describe '#write_hieradata_to' do
    let (:default_repo_content)  { <<-EOF
# SIMP Dependencies Yum Repository
[simp_dependencies]
name=simp-project-6_X_Dependencies
gpgcheck=1
enabled=1
baseurl=https://packagecloud.io/simp-project/6_X_Dependencies/el/$releasever/$basearch
gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
       https://yum.puppet.com/RPM-GPG-KEY-puppetlabs
       https://yum.puppet.com/RPM-GPG-KEY-puppet
       https://apt.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-96
       https://artifacts.elastic.co/GPG-KEY-elasticsearch
       https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
       https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$releasever
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF
    }
    let (:nondefault_repo_content)  { <<-EOF
# SIMP Dependencies Yum Repository
[simp_dependencies]
name=simp-project-7_X_dependencies
gpgcheck=0
enabled=1
baseurl=https://packagecloud.io/simp-project/7_X_dependencies/el/$releasever/$basearch
gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
       https://yum.puppet.com/RPM-GPG-KEY-puppetlabs
       https://yum.puppet.com/RPM-GPG-KEY-puppet
       https://apt.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-96
       https://artifacts.elastic.co/GPG-KEY-elasticsearch
       https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
       https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$releasever
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF
    }
    context 'defailt settings' do
      before(:all) { install_simp_deps_repo(host) }
      after(:all) { on(host, "rm -rf /etc/yum.repos.d/simp_dependencies.repo") }

      it 'creates the repo' do
        on host, 'test -f /etc/yum.repos.d/simp_dependencies.repo'
      end

      it 'writes the correct contents to the correct file' do
        stdout = on(host, 'cat /etc/yum.repos.d/simp_dependencies.repo').stdout
        expect(stdout).to eq(default_repo_content)
      end
    end

    context 'when passed a hash' do
      before(:all) { install_simp_deps_repo(host, '7_X_dependencies', '0' ) }
      after(:all) { on(host, "rm -rf /etc/yum.repos.d/simp_dependencies.repo") }

      it 'creates the repo' do
        on host, 'test -f /etc/yum.repos.d/simp_dependencies.repo'
      end

      it 'writes the correct contents to the correct file' do
        stdout = on(host, 'cat /etc/yum.repos.d/simp_dependencies.repo').stdout
        expect(stdout).to eq(nondefault_repo_content)
      end
    end
  end
end
