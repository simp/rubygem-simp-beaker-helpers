require 'spec_helper_acceptance'

hosts.each do |host|
  describe '#write_hieradata_to' do
    context 'when passed a YAML string' do
      before(:all) { set_hieradata_on(host, "---\n") }
      after(:all) { on(host, "rm -rf #{hiera_datadir(host)}") }

      it 'creates the datadir' do
        on host, "test -d #{hiera_datadir(host)}"
      end

      it 'writes the correct contents to the correct file' do
        stdout = on(host, "cat #{hiera_datadir(host)}/common.yaml").stdout
        expect(stdout).to eq("---\n")
      end
    end

    context 'when passed a hash' do
      before(:all) { set_hieradata_on(host, { 'foo' => 'bar' }) }
      after(:all) { on(host, "rm -rf #{hiera_datadir(host)}") }

      it 'creates the datadir' do
        on host, "test -d #{hiera_datadir(host)}"
      end

      it 'writes the correct contents to the correct file' do
        stdout = on(host, "cat #{hiera_datadir(host)}/common.yaml").stdout
        expect(stdout).to eq("---\nfoo: bar\n")
      end
    end
  end
end
