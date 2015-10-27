require 'spec_helper_acceptance'

context 'pfact_on operations' do
  before(:all) do
    copy_fixture_modules_to( hosts )
    pluginsync_on( [master] )
  end

  describe "pfact_on(master,'root_home')" do
    it 'should return value of root_home' do
      expect( pfact_on(master, 'root_home')).to_not be_nil
    end
  end
end
