require 'spec_helper_acceptance'

hosts.each do |host|
  describe '#set_hieradata_on' do
    context 'when passed a YAML string' do
      before(:all) { set_hieradata_on(host, "---\n") }
      after(:all) { on(host, "rm -rf #{host.puppet['hiera_config']} #{hiera_datadir(host)}") }

      it 'creates the datadir' do
        on host, "test -d #{hiera_datadir(host)}"
      end

      it 'writes to the configuration file' do
        stdout = on(host, "cat #{host.puppet['hiera_config']}").stdout
        expect(stdout).to match(":hierarchy:\n- default")
      end

      it 'writes the correct contents to the correct file' do
        stdout = on(host, "cat #{hiera_datadir(host)}/default.yaml").stdout
        expect(stdout).to eq("---\n")
      end
    end

    context 'when passed a hash' do
      before(:all) { set_hieradata_on(host, { 'foo' => 'bar' }) }
      after(:all) { on(host, "rm -rf #{host.puppet['hiera_config']} #{hiera_datadir(host)}") }

      it 'creates the datadir' do
        on host, "test -d #{hiera_datadir(host)}"
      end

      it 'writes the correct contents to the correct file' do
        stdout = on(host, "cat #{hiera_datadir(host)}/default.yaml").stdout
        expect(stdout).to eq("---\nfoo: bar\n")
      end
    end

    context 'when the terminus is set' do
      before(:all) { set_hieradata_on(host, "---\n", 'not-default') }
      after(:all) { on(host, "rm -rf #{host.puppet['hiera_config']} #{hiera_datadir(host)}") }

      it 'creates the datadir' do
        on host, "test -d #{hiera_datadir(host)}"
      end

      it 'writes the correct hierarchy to the configuration file' do
        stdout = on(host, "cat #{host.puppet['hiera_config']}").stdout
        expect(stdout).to match(":hierarchy:\n- not-default")
      end

      it 'writes the correct contents to the correct file' do
        stdout = on(host, "cat #{hiera_datadir(host)}/not-default.yaml").stdout
        expect(stdout).to eq("---\n")
      end
    end

    context 'when configuration management is disabled' do
      before(:all) { set_hieradata_on(host, "---\n", 'default', :manage_config => false) }
      after(:all) { on(host, "rm -rf #{host.puppet['hiera_config']} #{hiera_datadir(host)}") }

      it 'creates the datadir' do
        on host, "test -d #{hiera_datadir(host)}"
      end

      it 'does not touch the hiera config' do
        on host, "test ! -e #{host.puppet['hiera_config']}"
      end
    end
  end
end
