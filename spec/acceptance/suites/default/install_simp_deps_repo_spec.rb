require 'spec_helper_acceptance'

hosts.each do |host|
  expect_failures = false
  if hosts_with_role(hosts, 'el9').include?(host)
    expect_failures = true
  end

  describe '#install_simp_repos' do
    it 'should install yum utils' do
      host.install_package('yum-utils')
    end

    context 'default settings' do
      before(:all) do
        install_simp_repos(host)
      rescue => e
        if expect_failures
          warn e.message
        else
          raise e
        end
      end

      it 'enables the correct repos' do
        skip "#{host} is not supported yet" if expect_failures
        on(host, 'yum -y list simp')
        on(host, 'yum -y list postgresql96')
      end
    end

    context 'when targeting a release type' do
      it 'adjusts the SIMP release target' do
        set_simp_repo_release(host, 'rolling')
        expect(file_content_on(host, '/etc/yum/vars/simpreleasetype').strip).to eq('rolling')
      end

      it 'lists the simp rpm' do
        skip "#{host} is not supported yet" if expect_failures
        on(host, 'yum list simp')
      end
    end

    context 'when passed a disabled list ' do
      before(:all) do
        install_simp_repos(host, ['simp-community-simp'] )
      rescue => e
        if expect_failures
          warn e.message
        else
          raise e
        end
      end

      it 'enables the correct repos' do
        skip "#{host} is not supported yet" if expect_failures
        on(host, 'yum -y list postgresql96')
      end

      it 'disables the correct repos' do
        on(host, 'yum -y list simp', :acceptable_exit_codes => [1])
      end
    end
  end
end
