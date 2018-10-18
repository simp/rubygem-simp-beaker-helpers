require 'spec_helper'
require 'simp/beaker_helpers'

# redefine methods used in RSpec.configure withing Simp::BeakerHelpers
def hosts; end
def activate_interfaces(hosts); end
def clear_temp_hieradata; end

class MyTestClass
  class FakeHost
    attr_accessor :options
    def initialize(opts = {})
      @options = opts
    end
  end

  include Simp::BeakerHelpers

  attr_accessor :host

  def initialize
    @host = FakeHost.new
  end
end

describe 'Simp::BeakerHelpers' do
  before :each do
    @helper = MyTestClass.new
  end

  let(:gem_search_results) {
    # subset of results, but still exercises code
    "puppet (5.5.1 ruby universal-darwin x64-mingw32 x86-mingw32, 5.5.0 ruby universal-darwin x64-mingw32 x86-mingw32, 5.4.0 ruby universal-darwin x64-mingw32 x86-mingw32, 5.3.6 ruby universal-darwin x64-mingw32 x86-mingw32, 5.3.5 ruby universal-darwin x64-mingw32 x86-mingw32, 5.3.4 ruby universal-darwin x64-mingw32 x86-mingw32, 5.3.3 ruby universal-darwin x64-mingw32 x86-mingw32, 5.3.2 ruby universal-darwin x64-mingw32 x86-mingw32, 5.3.1 ruby universal-darwin x64-mingw32 x86-mingw32, 5.2.0 ruby universal-darwin x64-mingw32 x86-mingw32, 5.1.0 ruby universal-darwin x64-mingw32 x86-mingw32, 5.0.1 ruby universal-darwin x64-mingw32 x86-mingw32, 5.0.0 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.11 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.10 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.9 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.8 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.7 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.6 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.5 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.4 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.1 ruby universal-darwin x64-mingw32 x86-mingw32, 4.10.0 ruby universal-darwin x64-mingw32 x86-mingw32, 4.9.4 ruby universal-darwin x64-mingw32 x86-mingw32, 4.9.3 ruby universal-darwin x64-mingw32 x86-mingw32, 4.9.2 ruby universal-darwin x64-mingw32 x86-mingw32, 4.9.1 ruby universal-darwin x64-mingw32 x86-mingw32, 4.9.0 ruby universal-darwin x64-mingw32 x86-mingw32, 4.8.2 ruby universal-darwin x64-mingw32 x86-mingw32, 4.8.1 ruby universal-darwin x64-mingw32 x86-mingw32, 4.8.0 ruby universal-darwin x64-mingw32 x86-mingw32)\n"
  }

  context '#latest_puppet_agent_version_for' do
    context 'using table' do
      it 'maps exact Puppet version' do
        expect( @helper.latest_puppet_agent_version_for('4.10.4') ).to eq '1.10.4'
      end

      # remaining tests are only for a sampling of version specifictions with
      # operators,  because we are really only testing that the version specification
      # is proper;ly handed off to Gem::Requirement(), not that Gem::Requirement works.
      it "maps to appropriate Puppet version when '=' operator specified in version" do
        expect( @helper.latest_puppet_agent_version_for('= 4.8') ).to eq '1.8.0'
      end

      it "maps to appropriate Puppet version when '~>' operator specified in version" do
        expect( @helper.latest_puppet_agent_version_for('~> 4.8.0') ).to eq '1.8.3'
      end

      it "maps to appropriate Puppet version when '<' operator specified in version" do
        expect( @helper.latest_puppet_agent_version_for('< 4.9') ).to match /1.8.3/
      end

      it "maps to appropriate Puppet version when comma-separated operators specified in version" do
        expect( @helper.latest_puppet_agent_version_for('>= 4.7, < 4.9') ).to match /1.8.3/
      end
    end

    context 'using gem lookup' do
      it 'maps exact Puppet version' do
        allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
        expect( @helper.latest_puppet_agent_version_for('5.3.1') ).to eq '5.3.1'
      end

      # remaining tests are only for a sampling of version specifictions with
      # operators,  because we are really only testing that the version specification
      # is proper;ly handed off to Gem::Requirement(), not that Gem::Requirement works.
      it "maps to appropriate Puppet version when '=' operator specified in version" do
        allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
        expect( @helper.latest_puppet_agent_version_for('= 5.5') ).to eq '5.5.0'
      end

      it "maps to appropriate Puppet version when '~>' operator specified in version" do
        allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
        expect( @helper.latest_puppet_agent_version_for('~> 5.3.0') ).to eq '5.3.6'
      end

      # this logic won't work properly without code changes that just aren't worth it because
      # Puppet 4 is MD soon....
      # it "maps to appropriate Puppet version when '<' operator specified in version" do
      #   pending 'fails because matches 4.x table'
      #   allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
      #   expect( @helper.latest_puppet_agent_version_for('< 5.5') ).to match /5.4.0/
      # end

      it "maps to appropriate Puppet version when comma-separated operators specified in version" do
        allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
        expect( @helper.latest_puppet_agent_version_for('>= 5, < 5.5') ).to match /5.4.0/
      end
    end
  end

  context '#get_puppet_install_info' do
    after (:each) do
      ENV['BEAKER_PUPPET_AGENT_VERSION'] = nil
      ENV['PUPPET_INSTALL_VERSION'] = nil
      ENV['PUPPET_VERSION'] = nil
      ENV['BEAKER_PUPPET_COLLECTION'] = nil
      ENV['PUPPET_INSTALL_TYPE'] = nil
    end

    it 'uses defaults when no environment variables are set' do
      expected = {
      :puppet_install_version   => Simp::BeakerHelpers::DEFAULT_PUPPET_AGENT_VERSION,
      :beaker_puppet_collection => nil,
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from PUPPET_INSTALL_VERSION for Puppet 4' do
      ENV['PUPPET_INSTALL_VERSION']= '4.10.5'
      expected = {
      :puppet_install_version   => '1.10.5',
      :beaker_puppet_collection => nil,
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from PUPPET_INSTALL_VERSION for Puppet 5' do
      allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
      ENV['PUPPET_INSTALL_VERSION']= '5.5.0'
      expected = {
      :puppet_install_version   => '5.5.0',
      :beaker_puppet_collection => 'puppet5',
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from PUPPET_INSTALL_VERSION even when BEAKER_PUPPET_COLLECTION is set' do
      allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
      ENV['PUPPET_INSTALL_VERSION']= '5.5.0'
      ENV['BEAKER_PUPPET_COLLECTION']= 'puppet6'
      expected = {
      :puppet_install_version   => '5.5.0',
      :beaker_puppet_collection => 'puppet5',
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from PUPPET_INSTALL_VERSION even when host puppet_collection option is set' do
      allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
      ENV['PUPPET_INSTALL_VERSION']= '5.5.0'
      @helper.host.options = {'puppet_collection' => 'puppet6'}
      expected = {
      :puppet_install_version   => '5.5.0',
      :beaker_puppet_collection => 'puppet5',
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from BEAKER_PUPPET_AGENT_VERSION' do
      ENV['BEAKER_PUPPET_AGENT_VERSION']= '4.10.5'
      expected = {
      :puppet_install_version   => '1.10.5',
      :beaker_puppet_collection => nil,
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from PUPPET_VERSION' do
      ENV['PUPPET_VERSION']= '4.10.5'
      expected = {
      :puppet_install_version   => '1.10.5',
      :beaker_puppet_collection => nil,
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from BEAKER_PUPPET_COLLECTION' do
      allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
      ENV['BEAKER_PUPPET_COLLECTION']= 'puppet5'
      expected = {
      :puppet_install_version   => '5.5.1',
      :beaker_puppet_collection => 'puppet5',
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from BEAKER_PUPPET_COLLECTION' do
      allow(@helper).to receive(:`).with('gem search -ra -e puppet').and_return(gem_search_results)
      @helper.host.options = {'puppet_collection' => 'puppet5'}
      expected = {
      :puppet_install_version   => '5.5.1',
      :beaker_puppet_collection => 'puppet5',
      :puppet_install_type      => 'agent'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'extracts info from PUPPET_INSTALL_TYPE' do
      ENV['PUPPET_INSTALL_TYPE'] = 'pe'
      expected = {
      :puppet_install_version   => Simp::BeakerHelpers::DEFAULT_PUPPET_AGENT_VERSION,
      :beaker_puppet_collection => nil,
      :puppet_install_type      => 'pe'
      }
      expect( @helper.get_puppet_install_info ).to eq expected
    end

    it 'fails when BEAKER_PUPPET_COLLECTION is invalid' do
      ENV['BEAKER_PUPPET_COLLECTION'] = 'PUPPET5'
      expect{ @helper.get_puppet_install_info }.to raise_error(/Error: Puppet Collection 'PUPPET5' must match/)
    end

    it 'fails when host options puppet_collection is invalid' do
      @helper.host.options = {'puppet_collection' => 'PUPPET5'}
      expect{ @helper.get_puppet_install_info }.to raise_error(/Error: Puppet Collection 'PUPPET5' must match/)
    end
  end
end
