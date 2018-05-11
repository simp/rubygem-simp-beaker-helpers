require 'spec_helper_acceptance'

hosts.each do |host|
  describe 'ensure FIPS mode matches ENV[BEAKER_fips]' do
    context "on #{host}" do
     it 'check /proc/sys/crypto/fips_enabled' do
        stdout = on(host, 'cat /proc/sys/crypto/fips_enabled').stdout.strip
        if ENV['BEAKER_fips'] == 'yes'
          expect(stdout).to eq("1")
        else
          expect(stdout).to eq("0")
        end
      end 
    end
  end
end
