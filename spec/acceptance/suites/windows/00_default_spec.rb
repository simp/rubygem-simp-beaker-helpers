require 'tmpdir'
require 'yaml'
require 'openssl'
require 'beaker-rspec'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    unless Simp::BeakerHelpers::Snapshot.exist?(host, 'puppet_installed')
      # Install Puppet
      if host.is_pe?
        install_pe
      else
        install_puppet
      end
    end
  end
end

RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  fix_errata_on(hosts)

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    begin
      copy_fixture_modules_to( hosts )

      nonwin = hosts.dup
      nonwin.delete_if {|h| h[:platform] =~ /windows/ }

      begin
        server = only_host_with_role(nonwin, 'server')
      rescue ArgumentError => e
        server = only_host_with_role(nonwin, 'default')
      end
      # Generate and install PKI certificates on each SUT
      Dir.mktmpdir do |cert_dir|
        run_fake_pki_ca_on(server, nonwin, cert_dir )
        nonwin.each{ |sut| copy_pki_to( sut, cert_dir, '/etc/pki/simp-testing' )}
      end

      # add PKI keys
      copy_keydist_to(server)
    rescue StandardError, ScriptError => e
      if ENV['PRY']
        require 'pry'; binding.pry
      else
        raise e
      end
    end
  end
end

describe 'windows' do

  let(:hieradata){{
    'test::foo' => 'test'
  }}

  let(:manifest){ 'notify { "test": message => lookup("test::foo")}' }

  hosts.each do |host|
    context "on #{host}" do

      let(:hiera_config){{
        'version' => 5,
        'hierarchy' => [
          {
            'name' => 'Common',
            'path' => 'common.yaml'
          },
          {
            'name' => 'SIMP Compliance Engine',
            'lookup_key' => 'compliance_markup::enforcement'
          }
        ],
        'defaults' => {
          'data_hash' => 'yaml_data',
          'datadir' => hiera_datadir(host)
        }
      }}

      if Simp::BeakerHelpers::Snapshot.exist?(host, 'puppet_installed')
        Simp::BeakerHelpers::Snapshot.restore(host, 'puppet_installed')
      else
        Simp::BeakerHelpers::Snapshot.save(host, 'puppet_installed')
      end

      describe 'windows hosts coexising with linux hosts' do
        context "on #{host}" do
          it 'should have puppet installed' do
            on(host, 'puppet --version')
          end

          it 'should be able to set the hiera config' do
            set_hiera_config_on(host, hiera_config)
          end

          it 'should be able to set the hieradata' do
            set_hieradata_on(host, hieradata)
          end

          it 'should be able to run puppet' do
            output = apply_manifest_on(host, manifest).stdout

            expect(output).to include "defined 'message' as 'test'"
          end
        end
      end
    end
  end
end
