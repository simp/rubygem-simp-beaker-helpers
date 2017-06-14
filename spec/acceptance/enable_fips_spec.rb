require 'spec_helper_fips'

hosts.each do |host|
  describe 'ensure FIPS in enabled' do
    context "on #{host}" do
     it 'check /proc/sys/crypto/fips_enabled = 1' do
        stdout = on(host, 'cat /proc/sys/crypto/fips_enabled').stdout.strip
        expect(stdout).to eq("1")
      end 
    end
  end
end
