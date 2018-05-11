require 'spec_helper_acceptance'

context 'after copy_fixture_modules_to( hosts )' do
  before(:all) do
    # This should automatically run pluginsync_on hosts
    copy_fixture_modules_to( hosts )
  end

  describe "fact_on(master,'root_home')" do
    it 'should not return value of `root_home`' do
      puts fact = fact_on(master, 'root_home')
      expect( fact ).to eq ''
    end
  end

  describe "pfact_on(master,'root_home')" do
    it 'should return value of `root_home`' do
      puts fact = pfact_on(master, 'root_home')
      expect( fact ).to eq '/root'
    end
  end
end
