require 'spec_helper_acceptance'

hosts.each do |host|
  describe '#write_hieradata_to' do

    it 'should install yum utils' do
      host.install_package('yum-utils')
    end

    context 'defailt settings' do
      before(:all) { install_simp_repos(host) }

      it 'creates the repo' do
        on host, 'test -f /etc/yum.repos.d/simp6.repo'
        on host, 'test -f /etc/yum.repos.d/simp6_deps.repo'
      end

      it 'enables the correct repos' do
        simp6info = on(host, '/usr/bin/yum repolist -v simp6 | grep ^Repo-status').stdout.strip
        expect(simp6info).to match(/.*Repo-status.*enabled.*/)
        simp6depsinfo = on(host, 'yum repolist -v simp6_deps| grep ^Repo-status').stdout.strip
        expect(simp6depsinfo).to match(/.*Repo-status.*enabled.*/)
      end
    end

    context 'when passed a disabled list ' do
      before(:all) { install_simp_repos(host, ['simp6'] ) }

      it 'creates the repo' do
        on host, 'test -f /etc/yum.repos.d/simp6.repo'
        on host, 'test -f /etc/yum.repos.d/simp6_deps.repo'
      end

      it 'enables the correct repos' do
        simp6info = on(host, 'yum repolist -v simp6 | grep ^Repo-status').stdout.strip
        expect(simp6info).to match(/.*Repo-status.*disabled.*/)
        simp6depsinfo = on(host, 'yum repolist -v simp6_deps| grep ^Repo-status').stdout.strip
        expect(simp6depsinfo).to match(/.*Repo-status.*enabled.*/)
      end
    end
  end
end
