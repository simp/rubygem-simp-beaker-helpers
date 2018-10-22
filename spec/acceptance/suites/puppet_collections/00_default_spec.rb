# This needs to be done so that we actually bring in a collection at the start
# of the run
#
# Choosing an arbitrary number in the middle of 5 so that we're not fooled by
# edge cases
#
ENV['PUPPET_VERSION'] = '5.1'

require 'spec_helper_acceptance'

Bundler.with_clean_env{
  %x{bundle exec rake spec_prep}
}

hosts.each do |host|
  describe 'make sure puppet version is valid' do
    context "on #{host}" do
      client_puppet_version = on(host, 'puppet --version').output.strip

      it "should be running puppet version #{ENV['PUPPET_VERSION']}}" do
        expect(Gem::Version.new(client_puppet_version)).to be >= Gem::Version.new(ENV['PUPPET_VERSION'])
      end
    end
  end
end
