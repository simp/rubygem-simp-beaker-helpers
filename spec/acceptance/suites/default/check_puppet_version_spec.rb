require 'spec_helper_acceptance'

hosts.each do |host|
  describe 'make sure puppet version is valid' do
    context "on #{host}" do
      puppet_collection = host.options[:puppet_collection]

      client_puppet_version = on(host, 'puppet --version').stdout.strip

      if puppet_collection =~ /puppet(\d+)/
        puppet_collection_version = $1

        it "should be running puppet version #{puppet_collection_version}" do
          expect(client_puppet_version.split('.').first).to eq(puppet_collection_version)
        end
      else
        it 'should be running puppet 6' do
          expect(client_puppet_version.split('.').first).to eq '6'
        end
      end
    end
  end
end
