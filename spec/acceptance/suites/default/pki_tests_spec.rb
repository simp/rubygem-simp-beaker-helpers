require 'spec_helper_acceptance'
require 'tmpdir'

context 'PKI operations' do
  context 'after run_fake_pki_ca_on(default,hosts)' do
    before(:all) do
      copy_fixture_modules_to(hosts)
    end

    shared_examples_for 'a correctly copied keydist/ tree' do |test_dir|
      it 'correctly copies keydist/ tree' do
        on(default, "ls -d #{test_dir}" \
                   " #{test_dir}/cacerts" \
                   " #{test_dir}/cacerts/cacert_*.pem")

        hosts.each do |host|
          name = host.node_name
          on(default, "ls -d #{test_dir}/#{name}/cacerts" \
                     " #{test_dir}/#{name}/#{name}.pem"  \
                     " #{test_dir}/#{name}/#{name}.pub"  \
                     " #{test_dir}/cacerts/cacert_*.pem")
        end
      end
    end

    describe 'a Fake CA under /root' do
      def tmp_keydist_dir
        @tmp_keydist_dir ||= Dir.mktmpdir 'simp-beaker-helpers__pki-tests'
      end

      before(:all) do
        run_fake_pki_ca_on(default, hosts, tmp_keydist_dir)
      end

      it 'creates /root/pki' do
        on(default, 'test -d /root/pki')
      end

      it_behaves_like 'a correctly copied keydist/ tree', '/root/pki/keydist'
    end

    describe 'after copy_keydist_to' do
      before(:all) do
        copy_keydist_to(default)
      end

      it_behaves_like 'a correctly copied keydist/ tree', '/etc/puppetlabs/code/environments/production/modules/pki/files/keydist'
    end

    describe 'after copy_keydist_to(default, "/tmp/foo")' do
      before(:all) do
        copy_keydist_to(default, '/tmp/foo')
      end

      it_behaves_like 'a correctly copied keydist/ tree', '/tmp/foo'
    end
  end
end
