require 'spec_helper_acceptance'

hosts.each do |host|
  describe 'FIPS enabled from Forge' do
    context "on #{host}" do
      if ENV['BEAKER_fips'] == 'yes'
        it 'creates an alternate apply directory' do
          on(host, 'test -d /root/.beaker_fips/modules')
        end

        it 'has fips enabled' do
          stdout = on(host, 'cat /proc/sys/crypto/fips_enabled').stdout.strip
          expect(stdout).to eq('1')
        end
      else
        it 'has fips disabled' do
          stdout = on(host, 'cat /proc/sys/crypto/fips_enabled').stdout.strip
          expect(stdout).to eq('0')
        end
      end
    end
  end
end
