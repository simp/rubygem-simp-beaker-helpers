require 'spec_helper_acceptance'

unless ENV['PUPPET_VERSION'] || ENV['BEAKER_PUPPET_COLLECTION']
  fail('You must set either PUPPET_VERSION or BEAKER_PUPPET_COLLECTION as an environment variable')
end

if ENV['BEAKER_PUPPET_COLLECTION']
  target_version = ENV['BEAKER_PUPPET_COLLECTION'][/(\d+)$/,1]
elsif ENV['PUPPET_VERSION']
  target_version = ENV['PUPPET_VERSION'].split('.').first
end

hosts.each do |host|
  describe 'make sure puppet version is valid' do
    context "on #{host}" do
      client_puppet_version = on(host, 'puppet --version').output.lines.last.strip

      it "should be running puppet version #{target_version}" do
        expect(Gem::Version.new(client_puppet_version)).to be >= Gem::Version.new(target_version)
      end
    end
  end
end
