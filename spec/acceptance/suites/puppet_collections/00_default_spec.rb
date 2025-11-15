require 'spec_helper_acceptance'

hosts.each do |host|
  describe 'make sure puppet version is valid' do
    context "on #{host}" do
      let(:target_version) do
        unless ENV['PUPPET_VERSION'] || ENV['BEAKER_PUPPET_COLLECTION']
          raise('You must set either PUPPET_VERSION or BEAKER_PUPPET_COLLECTION as an environment variable')
        end

        if ENV['BEAKER_PUPPET_COLLECTION']
          ENV['BEAKER_PUPPET_COLLECTION'][%r{(\d+)$}, 1]
        elsif ENV['PUPPET_VERSION']
          ENV['PUPPET_VERSION'].split('.').first
        end
      end

      let(:client_puppet_version) { on(host, 'puppet --version').output.lines.last.strip }

      it "is running puppet version #{target_version}" do
        expect(Gem::Version.new(client_puppet_version)).to be >= Gem::Version.new(target_version)
      end
    end
  end
end
