require 'spec_helper_acceptance'

context 'after copy_fixture_modules_to( hosts )' do
  before(:all) do
    # This should automatically run pluginsync_on hosts
    copy_fixture_modules_to(hosts)
  end

  describe "fact_on(default,'root_home')" do
    it 'does not return value of `root_home`' do
      pending "Conflicts with beaker_puppet_helpers" if Gem::Version.new(Puppet.version) >= Gem::Version.new('8')
      expect(Beaker::DSL::Helpers::FacterHelpers.fact_on(default, 'root_home').to_s).to eq ''
    end
  end

  describe "pfact_on(default,'root_home')" do
    it 'returns value of `root_home`' do
      expect(pfact_on(default, 'root_home')).to eq '/root'
    end
  end

  describe "pfact_on(default,'os.release.major')" do
    it 'returns the value of `os.release.major`' do
      expect(pfact_on(default, 'os.release.major')).to match(%r{.+})
    end
  end

  describe "pfact_on(default,'os.release.foo')" do
    it 'does not return the value of `os.release.foo`' do
      expect(pfact_on(default, 'os.release.foo').to_s).to eq ''
    end
  end

  describe "pfact_on(default,'fips_enabled')" do
    expected = (ENV['BEAKER_fips'] == 'yes')

    it 'returns false' do
      expect(pfact_on(default, 'fips_enabled')).to eq expected
    end
  end

  describe 'pfact_on returns a hash' do
    it 'returns a Hash' do
      expect(pfact_on(default, 'os')).to be_a(Hash)
    end
  end
end
