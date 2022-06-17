require 'spec_helper_acceptance'

hosts.each do |host|
  describe 'FIPS enabled from Forge' do
    context "on #{host}" do
      if ENV['BEAKER_fips'] == 'yes'
        it 'creates an alternate apply directory' do
          on(host, 'test -d /root/.beaker_fips/modules')
        end

        it 'has fips enabled' do
          if host[:hypervisor] == 'docker'
            skip('Not supported on docker')
          else
            expect(fips_enabled(host)).to be true
          end
        end
      else
        it 'has fips disabled' do
          expect(fips_enabled(host)).to be false
        end
      end
    end
  end
end
