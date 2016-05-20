module Simp; end

module Simp::BeakerHelpers
  VERSION = '1.0.11'

  # use the `puppet fact` face to look up facts on an SUT
  def pfact_on(sut, fact_name)
    facts_json = on(sut,'puppet facts find xxx').output
    facts      = JSON.parse(facts_json).fetch( 'values' )
    facts.fetch(fact_name)
  end


  # Locates .fixture.yml in or above this directory.
  def fixtures_yml_path
    STDERR.puts '  ** fixtures_yml_path' if ENV['BEAKER_helpers_verbose']
    fixtures_yml = ''
    dir          = '.'
    while( fixtures_yml.empty? && File.expand_path(dir) != '/' ) do
      file = File.expand_path( '.fixtures.yml', dir )
      STDERR.puts "  ** fixtures_yml_path: #{file}" if ENV['BEAKER_helpers_verbose']
      if File.exists? file
        fixtures_yml = file
        break
      end
      dir = "#{dir}/.."
    end
    raise 'ERROR: cannot locate .fixtures.yml!' if fixtures_yml.empty?
    STDERR.puts "  ** fixtures_yml_path:finished (file: '#{file}')" if ENV['BEAKER_helpers_verbose']
    fixtures_yml
  end


  # returns an Array of puppet modules declared in .fixtures.yml
  def pupmods_in_fixtures_yml
    STDERR.puts '  ** pupmods_in_fixtures_yml' if ENV['BEAKER_helpers_verbose']
    fixtures_yml = fixtures_yml_path
    data         = YAML.load_file( fixtures_yml )
    repos        = data.fetch('fixtures').fetch('repositories', {}).keys || []
    symlinks     = data.fetch('fixtures').fetch('symlinks', {}).keys     || []
    STDERR.puts '  ** pupmods_in_fixtures_yml: finished' if ENV['BEAKER_helpers_verbose']
    (repos + symlinks)
  end


  # Ensures that the fixture modules (under `spec/fixtures/modules`) exists.
  # if any fixture modules are missing, run 'rake spec_prep' to populate the
  # fixtures/modules
  def ensure_fixture_modules
    STDERR.puts "  ** ensure_fixture_modules" if ENV['BEAKER_helpers_verbose']
    unless ENV['BEAKER_spec_prep'] == 'no'
      puts "== checking prepped modules from .fixtures.yml"
      puts "  -- (use BEAKER_spec_prep=no to disable)"
      missing_modules = []
      pupmods_in_fixtures_yml.each do |pupmod|
        STDERR.puts "  **  -- ensure_fixture_modules: '#{pupmod}'" if ENV['BEAKER_helpers_verbose']
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
    STDERR.puts "  **  -- ensure_fixture_modules: finished" if ENV['BEAKER_helpers_verbose']
  end


  # Copy the local fixture modules (under `spec/fixtures/modules`) onto each SUT
  def copy_fixture_modules_to( suts = hosts, opts = {:pluginsync => true,
                                                     :target_module_path => '/etc/puppetlabs/code/modules'} )

    # FIXME: As a result of BKR-723, which does not look easy to fix, we cannot rely on copy_module_to()
    # choosing a sane default for target_module_path.  In the event that BKR-723 is fixed, then the default
    # specified here should be removed.

    !suts.is_a?( Array ) and suts = Array(suts)

    STDERR.puts '  ** copy_fixture_modules_to' if ENV['BEAKER_helpers_verbose']
    ensure_fixture_modules

    unless ENV['BEAKER_copy_fixtures'] == 'no'
      suts.each do |sut|
        STDERR.puts "  ** copy_fixture_modules_to: '#{sut}'" if ENV['BEAKER_helpers_verbose']
        # allow spec_prep to provide modules (to support isolated networks)
        unless ENV['BEAKER_use_fixtures_dir_for_modules'] == 'no'
          pupmods_in_fixtures_yml.each do |pupmod|
            STDERR.puts "  ** copy_fixture_modules_to: '#{sut}': '#{pupmod}'" if ENV['BEAKER_helpers_verbose']
            mod_root = File.expand_path( "spec/fixtures/modules/#{pupmod}", File.dirname( fixtures_yml_path ))
            opts = opts.merge({:source => mod_root,
                               :module_name => pupmod})
            copy_module_to( sut, opts )
          end
        end
      end
    end
    STDERR.puts '  ** copy_fixture_modules_to: finished' if ENV['BEAKER_helpers_verbose']

    # sync custom facts from the new modules to each SUT's factpath
    pluginsync_on(suts) if opts[:pluginsync]
  end


  # Configure and reboot SUTs into FIPS mode
  def enable_fips_mode_on( suts = hosts )
    puts '== configuring FIPS mode on SUTs'
    puts '  -- (use BEAKER_fips=no to disable)'
    suts.each do |sut|
      puts "  -- enabling FIPS on '#{sut}'"

      # We need to use FIPS compliant algorithms and keylengths as per the FIPS
      # certification.
      on(sut, 'puppet config set digest_algorithm sha256')
      on(sut, 'puppet config set keylength 2048')

      # We need to be able to get back into our system!
      # Make these safe for all systems, even old ones.
      fips_ssh_ciphers = [ 'aes256-cbc','aes192-cbc','aes128-cbc']
      on(sut, %(sed -i '/Ciphers /d' /etc/ssh/sshd_config))
      on(sut, %(echo 'Ciphers #{fips_ssh_ciphers.join(',')}' >> /etc/ssh/sshd_config))

      if fact_on(sut, 'osfamily') == 'RedHat'
        pp = <<-EOS
        # This is necessary to prevent a kernel panic after rebooting into FIPS
        # (last checked: 20150928)
          package { ['kernel'] : ensure => 'latest' }

          package { ['grubby'] : ensure => 'latest' }
          ~>
          exec{ 'setup_fips':
            command     => '/bin/bash /root/setup_fips.sh',
            refreshonly => true,
          }

          file{ '/root/setup_fips.sh':
            ensure  => 'file',
            owner   => 'root',
            group   => 'root',
            mode    => '0700',
            content => "#!/bin/bash

# FIPS
if [ -e /sys/firmware/efi ]; then
  BOOTDEV=`df /boot/efi | tail -1 | cut -f1 -d' '`
else
  BOOTDEV=`df /boot | tail -1 | cut -f1 -d' '`
fi
# In case you need a working fallback
DEFAULT_KERNEL_INFO=`/sbin/grubby --default-kernel`
DEFAULT_INITRD=`/sbin/grubby --info=\\\${DEFAULT_KERNEL_INFO} | grep initrd | cut -f2 -d'='`
DEFAULT_KERNEL_TITLE=`/sbin/grubby --info=\\\${DEFAULT_KERNEL_INFO} | grep -m1 title | cut -f2 -d'='`
/sbin/grubby --copy-default --make-default --args=\\\"boot=\\\${BOOTDEV} fips=1\\\" --add-kernel=`/sbin/grubby --default-kernel` --initrd=\\\${DEFAULT_INITRD} --title=\\\"FIPS \\\${DEFAULT_KERNEL_TITLE}\\\"
",
            notify => Exec['setup_fips']
          }
        EOS
        apply_manifest_on(sut, pp, :catch_failures => false)
        on( sut, 'shutdown -r now', { :expect_connection_failure => true } )
      end
    end
  end


  # Apply known OS fixes we need to run Beaker on each SUT
  def fix_errata_on( suts = hosts )

    suts.each do |sut|
      # SIMP uses structured facts, therefore stringify_facts must be disabled
      unless ENV['BEAKER_stringify_facts'] == 'yes'
        on sut, 'puppet config set stringify_facts false'
      end

      # Occasionally we run across something similar to BKR-561, so to ensure we
      # at least have the host defaults:
      #
      # :hieradatadir is used as a canary here; it isn't the only missing key
      unless sut.host_hash.key? :hieradatadir 
        configure_type_defaults_on(sut)
      end

      if fact_on(sut, 'osfamily') == 'RedHat'
        # net-tools required for netstat utility being used by be_listening
        if fact_on(sut, 'operatingsystemmajrelease') == '7'
          pp = <<-EOS
            package { 'net-tools': ensure => installed }
          EOS
          apply_manifest_on(sut, pp, :catch_failures => false)
        end
      end

    end

    # Configure and reboot SUTs into FIPS mode
    unless ENV['BEAKER_fips'] == 'no'
      enable_fips_mode_on(suts)
    end

    # Clean up YUM prior to starting our test runs.
    on(suts, 'yum clean all')
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

    # if a local_dir was provided, copy everything down to it
    unless local_dir.empty?
      FileUtils.mkdir_p local_dir
      scp_from( ca_sut, host_dir, local_dir )
    end
  end


  # Copy a single SUT's PKI certs (with cacerts) onto an SUT.
  #
  # This simulates the result of pki::copy
  #
  # The directory structure is:
  #
  # SUT_BASE_DIR/
  #             pki/
  #                 cacerts/cacerts.pem
  #                 public/fdqn.pub
  #                 private/fdqn.pem
  def copy_pki_to(sut, local_pki_dir, sut_base_dir = '/etc/pki/simp-testing')
      fqdn                = fact_on(sut, 'fqdn')
      sut_pki_dir         = File.join( sut_base_dir, 'pki' )
      local_host_pki_tree = File.join(local_pki_dir,'pki','keydist',fqdn)
      local_cacert = File.join(local_pki_dir,'pki','demoCA','cacert.pem')

      on sut, %Q(mkdir -p "#{sut_pki_dir}/public" "#{sut_pki_dir}/private" "#{sut_pki_dir}/cacerts")
      scp_to(sut, "#{local_host_pki_tree}/#{fqdn}.pem",   "#{sut_pki_dir}/private/")
      scp_to(sut, "#{local_host_pki_tree}/#{fqdn}.pub",   "#{sut_pki_dir}/public/")

      # NOTE: to match pki::copy, 'cacert.pem' is renamed to 'cacerts.pem'
      scp_to(sut, local_cacert, "#{sut_pki_dir}/cacerts/cacerts.pem")
  end


  # Copy a CA keydist/ directory of CA+host certs into an SUT
  #
  # This simulates the output of FakeCA's gencerts_nopass.sh to keydist/
  def copy_keydist_to( ca_sut = master, host_keydist_dir = nil  )
    if !host_keydist_dir
      modulepath = on(ca_sut, 'puppet config print modulepath --environment production' ).output.chomp.split(':')
      host_keydist_dir = "#{modulepath.first}/pki/files/keydist"
    end
    on ca_sut, "rm -rf #{host_keydist_dir}/*"
    on ca_sut, "mkdir -p #{host_keydist_dir}/"
    on ca_sut, "cp -pR /root/pki/keydist/. #{host_keydist_dir}/"
    on ca_sut, "chgrp -R puppet #{host_keydist_dir}"
  end


  ## Inline Hiera Helpers ##
  ## These will be integrated into core Beaker at some point ##

  # Set things up for the inline hieradata functions 'set_hieradata_on'
  # and 'clear_temp_hieradata'
  #
  #
  require 'rspec'
  RSpec.configure do |c|
    c.before(:all) do
      @temp_hieradata_dirs = @temp_hieradata_dirs || []
    end

    c.after(:all) do
      clear_temp_hieradata
    end
  end


  # Set the hiera data file on the provided host to the passed data structure
  #
  # Note: This is authoritative, you cannot mix this with other hieradata copies
  #
  # @param[sut, Array<Host>, String, Symbol] One or more hosts to act upon.
  #
  # @param[heradata, Hash || String] The full hiera data structure to write to the system.
  #
  # @param[data_file, String] The filename (not path) of the hiera data
  #                           YAML file to write to the system.
  #
  # @param[hiera_config, Array<String>] The hiera config array to write
  #                                     to the system. Must contain the
  #                                     Data_file name as one element.
  def set_hieradata_on(sut, hieradata, data_file='default')
    # Keep a record of all temporary directories that are created
    #
    # Should be cleaned by calling `clear_temp_hiera data` in after(:all)
    #
    # Omit this call to be able to delve into the hiera data that is
    # being created
    @temp_hieradata_dirs = @temp_hieradata_dirs || []

    data_dir = Dir.mktmpdir('hieradata')
    @temp_hieradata_dirs << data_dir

    fh = File.open(File.join(data_dir,"#{data_file}.yaml"),'w')
    if hieradata.kind_of? String
      fh.puts(hieradata)
    else
      fh.puts(hieradata.to_yaml)
    end

    fh.close

    # If there is already a directory on the system, the SCP below will
    # add the local directory to the existing directory instead of
    # replacing the contents.
    apply_manifest_on(
      sut,
      "file { '#{hiera_datadir(sut)}': ensure => 'absent', force => true, recurse => true }"
    )

    copy_hiera_data_to(sut, data_dir)
    write_hiera_config_on(sut, Array(data_file))
  end


  # Clean up all temporary hiera data files.
  #
  # Meant to be called from after(:all)
  def clear_temp_hieradata
    if @temp_hieradata_dirs && !@temp_hieradata_dirs.empty?
      @temp_hieradata_dirs.each do |data_dir|
        if File.exists?(data_dir)
          FileUtils.rm_r(data_dir)
        end
      end
    end
  end


  # pluginsync custom facts for all modules
  def pluginsync_on( suts = hosts )
    suts.each do |sut|
      fact_path = on(sut, %q(puppet config print factpath)).output.strip.split(':').first
      on(sut, %q(puppet config print modulepath)).output.strip.split(':').each do |mod_path|
        on(sut, %Q(mkdir -p #{fact_path}))
        next if on(sut, "ls #{mod_path}/*/lib/facter 2>/dev/null ", :accept_all_exit_codes => true).exit_code != 0
        on(sut, %Q(find #{mod_path}/*/lib/facter -type f -name '*.rb' -exec cp -a {} '#{fact_path}/' \\; ))
      end
    end
  end
end
