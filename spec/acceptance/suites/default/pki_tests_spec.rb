require 'spec_helper_acceptance'
require 'tmpdir'


context 'PKI operations' do

  context 'after run_fake_pki_ca_on(master,hosts)' do
    before(:all) do
      copy_fixture_modules_to( hosts )
    end

    shared_examples_for 'a correctly copied keydist/ tree' do |test_dir|
      it 'correctly copies keydist/ tree' do
        on(master, "ls -d #{test_dir}" +
                   " #{test_dir}/cacerts" +
                   " #{test_dir}/cacerts/cacert_*.pem"
          )

        hosts.each do |host|
          name = host.node_name
          on(master, "ls -d #{test_dir}/#{name}/cacerts" +
                     " #{test_dir}/#{name}/#{name}.pem"  +
                     " #{test_dir}/#{name}/#{name}.pub"  +
                     " #{test_dir}/cacerts/cacert_*.pem"
            )
        end
      end
    end

    describe 'a Fake CA under /root' do
      tmp_keydist_dir = Dir.mktmpdir 'simp-beaker-helpers__pki-tests'
      run_fake_pki_ca_on( master, hosts, tmp_keydist_dir  )

      it 'should create /root/pki' do
        on(master, 'test -d /root/pki')
      end

      it_behaves_like 'a correctly copied keydist/ tree', '/root/pki/keydist'

    end

    describe 'after copy_keydist_to' do
      test_dir = '/etc/puppetlabs/code/environments/production/modules/pki/files/keydist'
      copy_keydist_to(master)
      it_behaves_like 'a correctly copied keydist/ tree', test_dir
    end

    describe 'after copy_keydist_to(master,"/tmp/foo")' do
      test_dir = '/tmp/foo'
      copy_keydist_to(master, test_dir)
      it_behaves_like 'a correctly copied keydist/ tree', test_dir
    end

  end
end
