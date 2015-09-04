module Simp; end

module Simp::BeakerHelpers
  VERSION = '1.0.0'

  # Locates .fixture.yml in or above this directory.
  def fixtures_yml_path
    fixtures_yml = ''
    dir          = '.'
    while( fixtures_yml.empty? && File.expand_path(dir) != '/' ) do
      file = File.expand_path( '.fixtures.yml', dir )
      if File.exists? file
        fixtures_yml = file
        break
      end
    end
    raise 'ERROR: cannot locate .fixtures.yml!' if fixtures_yml.empty?
    fixtures_yml
  end


  # returns an Array of puppet modules declared in .fixtures.yml
  def pupmods_in_fixtures_yml
    fixtures_yml = fixtures_yml_path
    data         = YAML.load_file( fixtures_yml )
    repos        = data.fetch('fixtures').fetch('repositories', {}).keys || []
    symlinks     = data.fetch('fixtures').fetch('symlinks', {}).keys     || []
    (repos + symlinks)
  end


  # Ensures that the fixture modules (under `spec/fixtures/modules`) exists.
  # if any fixture modules are missing, run 'rake spec_prep' to populate the
  # fixtures/modules
  def ensure_fixture_modules
    unless ENV['BEAKER_spec_prep'] == 'no'
      puts "== checking prepped modules from .fixtures.yml"
      missing_modules = []
      pupmods_in_fixtures_yml.each do |pupmod|
        mod_root = File.expand_path( "spec/fixtures/modules/#{pupmod}", File.dirname( fixtures_yml_path ))
        missing_modules << pupmod unless File.directory? mod_root
      end
      puts "  -- #{missing_modules.size} modules need to be prepped"
      unless missing_modules.empty?
        cmd = 'bundle exec rake spec_prep'
        puts "  -- running spec_prep: '#{cmd}'"
        %x(#{cmd})
      else
        puts "  == all fixture modules present"
      end
    end
  end

  # Copy the local fixture modules (under `spec/fixtures/modules`) onto each SUT
  def copy_fixture_modules_to( suts = hosts )
    ensure_fixture_modules
    suts.each do |sut|
      # allow spec_prep to provide modules (to support isolated networks)
      unless ENV['BEAKER_use_fixtures_dir_for_modules'] == 'no'
        pupmods_in_fixtures_yml.each do |pupmod|
          mod_root = File.expand_path( "spec/fixtures/modules/#{pupmod}", File.dirname( fixtures_yml_path ))
          copy_module_to( sut, {:source => mod_root, :module_name => pupmod} )
        end
      end
    end
  end


  # Apply known OS fixes we need to run Beaker on each SUT
  def fix_errata_on( suts = hosts )
    suts.each do |sut|
      # net-tools required for netstat utility being used by be_listening
      if fact_on(sut, 'osfamily') == 'RedHat' && fact_on(sut, 'operatingsystemmajrelease') == '7'
        pp = <<-EOS
          package { 'net-tools': ensure => installed }
        EOS
        apply_manifest_on(sut, pp, :catch_failures => false)
      end
    end
  end


  # Generate a fake openssl CA + certs for each host on a given SUT
  #
  # The directory structure is the same as what FakeCA drops into keydist/
  #
  # NOTE: This generates everything within an SUT and copies it back out.
  #       This is because it is assumed the SUT will have the appropriate
  #       openssl in its environment, which may not be true of the host.
  def run_fake_pki_ca_on( ca_sut = master, suts = hosts, local_dir = '' )
    puts "== Fake PKI CA"
    pki_dir  = File.expand_path( "../../files/pki", File.dirname(__FILE__))
    host_dir = '/root/pki'
    fqdns    = fact_on hosts, 'fqdn'

    on ca_sut, %Q(mkdir -p "#{host_dir}")
    Dir[ File.join(pki_dir, '*')].each {|f| scp_to( ca_sut, f, host_dir)}

    # generate PKI certs for each SUT
    Dir.mktmpdir do |dir|
      pki_hosts_file = File.join(dir, 'pki.hosts')
      File.open(pki_hosts_file, 'w'){|fh| fqdns.each{|fqdn| fh.puts fqdn}}
      scp_to(ca_sut, pki_hosts_file, host_dir)
      # generate certs
      on ca_sut, "cd #{host_dir}; cat #{host_dir}/pki.hosts | xargs bash make.sh"
    end

    scp_from( ca_sut, host_dir, local_dir ) unless local_dir.empty?
  end


  # Copy a single SUT's PKI certs (with cacerts) onto an SUT.
  #
  # This simulates the result of pki::copy
  #
  # The directory structure is:
  #
  # HOST_PKI_DIR/
  #         cacerts/cacert.pem
  #         public/fdqn.pub
  #         private/fdqn.pem
  def copy_pki_to(sut, local_pki_dir, sut_pki_dir = '/etc/pki/simp-testing')
      fqdn = fact_on(sut, 'fqdn')
      local_host_pki_tree   = File.join(local_pki_dir,'pki','keydist',fqdn)
      ###local_cacert_pki_tree = File.join(local_pki_dir,'pki','keydist','cacerts')
      local_cacert = File.join(local_pki_dir,'pki','demoCA','cacert.pem')
      on sut, %Q(mkdir -p "#{sut_pki_dir}/public" "#{sut_pki_dir}/private" "#{sut_pki_dir}/cacerts")
      scp_to(sut, "#{local_host_pki_tree}/#{fqdn}.pem",   "#{sut_pki_dir}/private/")
      scp_to(sut, "#{local_host_pki_tree}/#{fqdn}.pub",   "#{sut_pki_dir}/public/")
      ###scp_to(sut, local_cacert_pki_tree, sut_pki_dir)
      scp_to(sut, local_cacert, "#{sut_pki_dir}/cacerts/")
  end


  # Copy a CA keydist/ directory of CA+host certs into an SUT
  #
  # This simulates the output of FakeCA's gencerts_nopass.sh to keydist/
  #
  # FIXME: update keydist to use a more flexible path
  def copy_keydist_to( ca_sut = master )
    modulepath = on(ca_sut, 'puppet config print  modulepath --environment production' ).output.chomp.split(':')
    on ca_sut, "rm -rf #{modulepath.first}/pki/files/keydist/*"
    on ca_sut, "cp -a /root/pki/keydist/ #{modulepath.first}/pki/files/"
    on ca_sut, "chgrp -R puppet #{modulepath.first}/pki/files/keydist"
  end
end
