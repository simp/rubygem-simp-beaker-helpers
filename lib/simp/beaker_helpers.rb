require 'beaker-puppet'
require 'bundler'

module Simp; end

module Simp::BeakerHelpers
  include BeakerPuppet

  require 'simp/beaker_helpers/constants'
  require 'simp/beaker_helpers/inspec'
  require 'simp/beaker_helpers/snapshot'
  require 'simp/beaker_helpers/ssg'
  require 'simp/beaker_helpers/version'
  require 'find'

  @run_in_parallel = (ENV['BEAKER_SIMP_parallel'] == 'yes')

  # Stealing this from the Ruby 2.5 Dir::Tmpname workaround from Rails
  def self.tmpname
    t = Time.new.strftime("%Y%m%d")
    "simp-beaker-helpers-#{t}-#{$$}-#{rand(0x100000000).to_s(36)}.tmp"
  end

  # Sets a single YUM option in the form that yum-config-manager/dnf
  # config-manager would expect.
  #
  # If not prefaced with a repository, the option will be applied globally.
  #
  # Has no effect if yum or dnf is not present.
  def set_yum_opt_on(suts, key, value)
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      repo,target = key.split('.')

      unless target
        key = "\\*.#{repo}"
      end

      command = nil
      if !sut.which('dnf').empty?
        install_package_unless_present_on(sut, 'dnf-plugins-core', :accept_all_exit_codes => true)
        command = 'dnf config-manager'
      elsif !sut.which('yum').empty?
        command = 'yum-config-manager'
      end

      on(sut, %{#{command} --save --setopt=#{key}=#{value}}, :silent => true) if command
    end
  end

  # Takes a hash of YUM options to set in the form that yum-config-manager/dnf
  # config-manager would expect.
  #
  # If not prefaced with a repository, the option will be applied globally.
  #
  # Example:
  #   {
  #     'skip_if_unavailable' => '1', # Applies globally
  #     'foo.installonly_limit' => '5' # Applies only to the 'foo' repo
  #   }
  def set_yum_opts_on(suts, yum_opts={})
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      yum_opts.each_pair do |k,v|
        set_yum_opt_on(sut, k, v)
      end
    end
  end

  def install_package_unless_present_on(suts, package_name, package_source=nil, opts={})
    default_opts = {
      max_retries: 3,
      retry_interval: 10
    }

    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      package_source = package_name unless package_source

      unless sut.check_for_package(package_name)
        sut.install_package(
          package_source,
          '',
          nil,
          default_opts.merge(opts)
        )
      end
    end
  end

  def install_latest_package_on(suts, package_name, package_source=nil, opts={})
    default_opts = {
      max_retries: 3,
      retry_interval: 10
    }

    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      package_source = package_name unless package_source

      if sut.check_for_package(package_name)
        sut.upgrade_package(
          package_source,
          '',
          default_opts.merge(opts)
        )
      else
        install_package_unless_present_on(sut, package_name, package_source, opts)
      end
    end
  end

  def is_windows?(sut)
    sut[:platform] =~ /windows/i
  end

  # We can't cache this because it may change during a run
  def fips_enabled(sut)
    return on( sut,
              'cat /proc/sys/crypto/fips_enabled 2>/dev/null',
              :accept_all_exit_codes => true
             ).output.strip == '1'
  end

  def rsync_functional_on?(sut)
    # We have to check if rsync *still* works otherwise
    return false if (@rsync_functional == false)

    require 'facter'
    unless Facter::Util::Resolution.which('rsync')
      @rsync_functional = false
      return @rsync_functional
    end

    require 'tempfile'

    testfile = Tempfile.new('rsync_check')
    testfile.puts('test')
    testfile.close

    begin
      rsync_to(sut, testfile.path, sut.system_temp_path)
    rescue Beaker::Host::CommandFailure
      @rsync_functional = false
      return false
    ensure
      testfile.unlink
    end

    return true
  end

  # Figure out the best method to copy files to a host and use it
  #
  # Will create the directories leading up to the target if they don't exist
  def copy_to(sut, src, dest, opts={})
    sut.mkdir_p(File.dirname(dest))

    if sut[:hypervisor] == 'docker'
      exclude_list = []
      opts[:silent] ||= true

      if opts.has_key?(:ignore) && !opts[:ignore].empty?
        opts[:ignore].each do |value|
          exclude_list << "--exclude '#{value}'"
        end
      end

      # Work around for breaking changes in beaker-docker
      if sut.host_hash[:docker_container]
        container_id = sut.host_hash[:docker_container].id
      else
        container_id = sut.host_hash[:docker_container_id]
      end

      if ENV['BEAKER_docker_cmd']
        docker_cmd = ENV['BEAKER_docker_cmd']
      else
        docker_cmd = 'docker'

        if ::Docker.version['Components'].any?{|x| x['Name'] =~ /podman/i}
          docker_cmd = 'podman'

          if ENV['CONTAINER_HOST']
            docker_cmd = 'podman --remote'
          elsif ENV['DOCKER_HOST']
            docker_cmd = "podman --remote --url=#{ENV['DOCKER_HOST']}"
          end
        end
      end

      sut.mkdir_p(File.dirname(dest)) unless directory_exists_on(sut, dest)

      if File.file?(src)
        cmd = %{#{docker_cmd} cp "#{src}" "#{container_id}:#{dest}"}
      else
        cmd = [
          %{tar #{exclude_list.join(' ')} -hcf - -C "#{File.dirname(src)}" "#{File.basename(src)}"},
          %{#{docker_cmd} exec -i "#{container_id}" tar -C "#{dest}" -xf -}
        ].join(' | ')
      end

      %x(#{cmd})
    elsif rsync_functional_on?(sut)
      # This makes rsync_to work like beaker and scp usually do
      exclude_hack = %(__-__' -L --exclude '__-__)

      # There appears to be a single copy of 'opts' that gets passed around
      # through all of the different hosts so we're going to make a local deep
      # copy so that we don't destroy the world accidentally.
      _opts = Marshal.load(Marshal.dump(opts))
      _opts[:ignore] ||= []
      _opts[:ignore] << exclude_hack

      if File.directory?(src)
        dest = File.join(dest, File.basename(src)) if File.directory?(src)
        sut.mkdir_p(dest)
      end

      # End rsync hackery

      begin
        rsync_to(sut, src, dest, _opts)
      rescue
        # Depending on what is getting tested, a new SSH session might not
        # work. In this case, we fall back to SSH.
        #
        # The rsync failure is quite fast so this doesn't affect performance as
        # much as shoving a bunch of data over the ssh session.
        scp_to(sut, src, dest, opts)
      end
    else
      scp_to(sut, src, dest, opts)
    end
  end

  # use the `puppet fact` face to look up facts on an SUT
  def pfact_on(sut, fact_name)
    found_fact = nil
    # If puppet is not installed, there are no puppet facts to fetch
    if sut.which('puppet').empty?
      found_fact = fact_on(sut, fact_name)
    else
      facts_json = nil
      begin
        cmd_output = on(sut, 'facter -p --json', :silent => true)
        # Facter 4+
        raise('skip facter -p') if (cmd_output.stderr =~ /no longer supported/)

        facts = JSON.parse(cmd_output.stdout)
      rescue StandardError
        # If *anything* fails, we need to fall back to `puppet facts`

        facts_json = retry_on(sut, 'puppet facts find garbage_xxx', :silent => true, :max_retries => 4).stdout
        facts = JSON.parse(facts_json)['values']
      end

      found_fact = facts.dig(*(fact_name.split('.')))

      # If we did not find a fact, we should use the upstream function since
      # puppet may be installed via a gem or through some other means.
      found_fact = fact_on(sut, fact_name) if found_fact.nil?
    end

    # Ensure that Hashes return as Hash objects
    # OpenStruct objects have a marshal_dump method
    found_fact.respond_to?(:marshal_dump) ? found_fact.marshal_dump : found_fact
  end

  # Returns the modulepath on the SUT, as an Array
  def puppet_modulepath_on(sut, environment='production')
    splitchar = ':'
    splitchar = ';' if is_windows?(sut)

    (
      sut.puppet_configprint['modulepath'].split(splitchar) +
      sut.puppet_configprint['basemodulepath'].split(splitchar)
    ).uniq
  end

  # Return the default environment path
  def puppet_environment_path_on(sut, environment='production')
    File.dirname(sut.puppet_configprint['manifest'])
  end

  # Return the path to the 'spec/fixtures' directory
  def fixtures_path
    return @fixtures_path if @fixtures_path

    STDERR.puts '  ** fixtures_path' if ENV['BEAKER_helpers_verbose']
    dir = RSpec.configuration.default_path
    dir = File.join('.', 'spec') unless dir

    dir = File.join(File.expand_path(dir), 'fixtures')

    if File.directory?(dir)
      @fixtures_path = dir
      return @fixtures_path
    else
      raise("Could not find fixtures directory at '#{dir}'")
    end
  end

  # Locates .fixture.yml in or above this directory.
  def fixtures_yml_path
    return @fixtures_yml_path if @fixtures_yml_path

    STDERR.puts '  ** fixtures_yml_path' if ENV['BEAKER_helpers_verbose']

    if ENV['FIXTURES_YML']
      fixtures_yml = ENV['FIXTURES_YML']
    else
      fixtures_yml = ''
      dir          = '.'
      while( fixtures_yml.empty? && File.expand_path(dir) != '/' ) do
        file = File.expand_path( '.fixtures.yml', dir )
        STDERR.puts "  ** fixtures_yml_path: #{file}" if ENV['BEAKER_helpers_verbose']
        if File.exist? file
          fixtures_yml = file
          break
        end
        dir = "#{dir}/.."
      end
    end

    raise 'ERROR: cannot locate .fixtures.yml!' if fixtures_yml.empty?

    STDERR.puts "  ** fixtures_yml_path:finished (file: '#{file}')" if ENV['BEAKER_helpers_verbose']

    @fixtures_yml_path = fixtures_yml

    return @fixtures_yml_path
  end


  # returns an Array of puppet modules declared in .fixtures.yml
  def pupmods_in_fixtures_yml
    return @pupmods_in_fixtures_yml if @pupmods_in_fixtures_yml

    STDERR.puts '  ** pupmods_in_fixtures_yml' if ENV['BEAKER_helpers_verbose']
    fixtures_yml = fixtures_yml_path
    data         = YAML.load_file( fixtures_yml )
    repos        = data.fetch('fixtures').fetch('repositories', {}).keys || []
    symlinks     = data.fetch('fixtures').fetch('symlinks', {}).keys     || []
    STDERR.puts '  ** pupmods_in_fixtures_yml: finished' if ENV['BEAKER_helpers_verbose']

    @pupmods_in_fixtures_yml = (repos + symlinks)

    return @pupmods_in_fixtures_yml
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
  def copy_fixture_modules_to( suts = hosts, opts = {})
    ensure_fixture_modules

    opts[:pluginsync] = opts.fetch(:pluginsync, true)

    unless ENV['BEAKER_copy_fixtures'] == 'no'
      block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
        STDERR.puts "  ** copy_fixture_modules_to: '#{sut}'" if ENV['BEAKER_helpers_verbose']

        # Use spec_prep to provide modules (this supports isolated networks)
        unless ENV['BEAKER_use_fixtures_dir_for_modules'] == 'no'

          # NOTE: As a result of BKR-723, which does not look easy to fix, we
          # cannot rely on `copy_module_to()` to choose a sane default for
          # `target_module_path`.  This workaround queries each SUT's
          # `modulepath` and targets the first one.
          target_module_path = puppet_modulepath_on(sut).first

          mod_root = File.expand_path( "spec/fixtures/modules", File.dirname( fixtures_yml_path ))

          Dir.chdir(mod_root) do
            # Have to do things the slow way on Windows
            if is_windows?(sut)
              begin
                zipfile = "#{Simp::BeakerHelpers.tmpname}.zip"
                files = []

                # 'zip -x' does not reliably exclude paths, so we need to remove them from
                #   the list of files to zip
                Dir.glob('*') do |module_root|
                  next unless Dir.exist?(module_root)
                  Find.find("#{module_root}/") do |path|
                    if PUPPET_MODULE_INSTALL_IGNORE.any? { |ignore| path.include?(ignore) }
                      Find.prune
                      next
                    end

                    files << path
                  end
                end

                command = ['zip', zipfile] + files
                Kernel.system(*command)

                raise("Error: module zip file '#{zipfile}' could not be created at #{mod_root}") unless File.exist?(zipfile)
                copy_to(sut, zipfile, target_module_path, opts)

                # Windows 2012 and R2 does not natively include PowerShell 5, in which
                #  the Expand-Archive cmdlet was introduced
                if fact_on(sut, 'os.release.major').include?('2012')
                  unzip_cmd = [
                    "\"[System.Reflection.Assembly]::LoadWithPartialName(\'System.IO.Compression.FileSystem\')",
                    "[System.IO.Compression.ZipFile]::OpenRead(\'#{target_module_path}\\#{File.basename(zipfile)}\').Entries.FullName \| %{Remove-Item -Path (\"\"\"#{target_module_path}\\$_\"\"\") -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue}", # rubocop:disable Layout/LineLength
                    "[System.IO.Compression.ZipFile]::ExtractToDirectory(\'#{target_module_path}\\#{File.basename(zipfile)}\', \'#{target_module_path}\')\"",
                  ].join(';')
                else
                  unzip_cmd = "$ProgressPreference='SilentlyContinue';Expand-Archive -Path #{target_module_path}\\#{File.basename(zipfile)} -DestinationPath #{target_module_path} -Force"
                end
                on(sut, powershell(unzip_cmd))
              ensure
                FileUtils.remove_entry(zipfile, true)
              end
            else
              begin
                tarfile = "#{Simp::BeakerHelpers.tmpname}.tar"

                excludes = (PUPPET_MODULE_INSTALL_IGNORE + ['spec']).map do |x|
                  x = "--exclude '*/#{x}'"
                end.join(' ')

                %x(tar -ch #{excludes} -f #{tarfile} *)

                if File.exist?(tarfile)
                  copy_to(sut, tarfile, target_module_path, opts)
                else
                  fail("Error: module tar file '#{tarfile}' could not be created at #{mod_root}")
                end

                on(sut, "cd #{target_module_path} && tar -xf #{File.basename(tarfile)}")
              ensure
                FileUtils.remove_entry(tarfile, true)
              end
            end
          end
        end
      end
    end
    STDERR.puts '  ** copy_fixture_modules_to: finished' if ENV['BEAKER_helpers_verbose']

    # sync custom facts from the new modules to each SUT's factpath
    pluginsync_on(suts) if opts[:pluginsync]
  end

  def has_crypto_policies(sut)
    file_exists_on(sut, '/etc/crypto-policies/config')
  end

  def munge_ssh_crypto_policies(suts, key_types=['ssh-rsa'])
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      if has_crypto_policies(sut)
        install_latest_package_on(sut, 'crypto-policies', nil, :accept_all_exit_codes => true)

        # Since we may be doing this prior to having a box flip into FIPS mode, we
        # need to find and modify *all* of the affected policies
        on( sut, %{sed --follow-symlinks -i 's/\\(HostKeyAlgorithms\\|PubkeyAcceptedKeyTypes\\)\\(.\\)/\\1\\2#{key_types.join(',')},/g' $( grep -L ssh-rsa $( find /etc/crypto-policies /usr/share/crypto-policies -type f -a \\( -name '*.txt' -o -name '*.config' \\) -exec grep -l PubkeyAcceptedKeyTypes {} \\; ) ) })
      end
    end
  end

  # Perform the equivalend of an in-place sed without changing the target inode
  #
  # Required for many container targets
  def safe_sed(suts = hosts, pattern, target_file)
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      tmpfile = sut.tmpfile('safe_sed')

      command = [
        "cp #{target_file} #{tmpfile}",
        "sed -i '#{pattern}' #{tmpfile}",
        "cat #{tmpfile} > #{target_file}"
      ].join(' && ')

      on(sut, command)

      sut.rm_rf(tmpfile)
    end
  end

  # Configure and reboot SUTs into FIPS mode
  def enable_fips_mode_on( suts = hosts )
    puts '== configuring FIPS mode on SUTs'
    puts '  -- (use BEAKER_fips=no to disable)'

    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      next if sut[:hypervisor] == 'docker'

      if is_windows?(sut)
        puts "  -- SKIPPING #{sut} because it is windows"
        next
      end

      puts "  -- enabling FIPS on '#{sut}'"

      # We need to use FIPS compliant algorithms and keylengths as per the FIPS
      # certification.
      on(sut, 'puppet config set digest_algorithm sha256')
      on(sut, 'puppet config set keylength 2048')

      # We need to be able to get back into our system!
      # Make these safe for all systems, even old ones.
      # TODO Use simp-ssh Puppet module appropriately (i.e., in a fashion
      #      that doesn't break vagrant access and is appropriate for
      #      typical module tests.)
      fips_ssh_ciphers = [ 'aes256-ctr','aes192-ctr','aes128-ctr']
      safe_sed(sut, '/Ciphers /d', '/etc/ssh/sshd_config')
      on(sut, %(echo 'Ciphers #{fips_ssh_ciphers.join(',')}' >> /etc/ssh/sshd_config))

      fips_enable_modulepath = ''

      if pupmods_in_fixtures_yml.include?('fips')
        copy_fixture_modules_to(sut)
      else
        # If we don't already have the simp-fips module installed
        #
        # Use the simp-fips Puppet module to set FIPS up properly:
        # Download the appropriate version of the module and its dependencies from PuppetForge.
        # TODO provide a R10k download option in which user provides a Puppetfile
        # with simp-fips and its dependencies
        on(sut, 'mkdir -p /root/.beaker_fips/modules')

        fips_enable_modulepath = '--modulepath=/root/.beaker_fips/modules'

        modules_to_install = {
          'simp-fips' => ENV['BEAKER_fips_module_version'],
          'simp-crypto_policy' => nil
        }

        modules_to_install.each_pair do |to_install, version|
          module_install_cmd = "puppet module install #{to_install} --target-dir=/root/.beaker_fips/modules"
          module_install_cmd += " --version #{version}" if version
          on(sut, module_install_cmd)
        end
      end

      # Work around Vagrant and cipher restrictions in EL8+
      #
      # Hopefully, Vagrant will update the used ciphers at some point but who
      # knows when that will be
      munge_ssh_crypto_policies(sut)

      # Enable FIPS and then reboot to finish.
      on(sut, %(puppet apply --verbose #{fips_enable_modulepath} -e "class { 'fips': enabled => true }"))

      sut.reboot
    end
  end

  # Collect all 'yum_repos' entries from the host nodeset.
  # The acceptable format is as follows:
  # yum_repos:
  #   <repo_name>:
  #     url: <URL>
  #     gpgkeys:
  #       - <URL to GPGKEY1>
  #       - <URL to GPGKEY2>
  def enable_yum_repos_on( suts = hosts )
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      if sut['yum_repos']
        sut['yum_repos'].each_pair do |repo, metadata|
          repo_manifest = create_yum_resource(repo, metadata)

          apply_manifest_on(sut, repo_manifest, :catch_failures => true)
        end
      end
    end
  end

  def create_yum_resource( repo, metadata )
    repo_attrs = [
      :assumeyes,
      :bandwidth,
      :cost,
      :deltarpm_metadata_percentage,
      :deltarpm_percentage,
      :descr,
      :enabled,
      :enablegroups,
      :exclude,
      :failovermethod,
      :gpgcakey,
      :gpgcheck,
      :http_caching,
      :include,
      :includepkgs,
      :keepalive,
      :metadata_expire,
      :metalink,
      :mirrorlist,
      :mirrorlist_expire,
      :priority,
      :protect,
      :provider,
      :proxy,
      :proxy_password,
      :proxy_username,
      :repo_gpgcheck,
      :retries,
      :s3_enabled,
      :skip_if_unavailable,
      :sslcacert,
      :sslclientcert,
      :sslclientkey,
      :sslverify,
      :target,
      :throttle,
      :timeout
    ]

      repo_manifest = %(yumrepo { #{repo}:)

      repo_manifest_opts = []

      # Legacy Support
      urls = !metadata[:url].nil? ? metadata[:url] : metadata[:baseurl]
      if urls
        repo_manifest_opts << 'baseurl => ' + '"' + Array(urls).flatten.join('\n        ').gsub('$','\$') + '"'
      end

      # Legacy Support
      gpgkeys = !metadata[:gpgkeys].nil? ? metadata[:gpgkeys] : metadata[:gpgkey]
      if gpgkeys
        repo_manifest_opts << 'gpgkey => ' + '"' + Array(gpgkeys).flatten.join('\n       ').gsub('$','\$') + '"'
      end

      repo_attrs.each do |attr|
        if metadata[attr]
          repo_manifest_opts << "#{attr} => '#{metadata[attr]}'"
        end
      end

      repo_manifest = repo_manifest + %(\n#{repo_manifest_opts.join(",\n")}) + "\n}\n"
  end

  # Enable EPEL if appropriate to do so and the system is online
  #
  # Can be disabled by setting BEAKER_enable_epel=no
  def enable_epel_on(suts)
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      if ONLINE
        os_info = fact_on(sut, 'os')
        os_maj_rel = os_info['release']['major']

        # This is based on the official EPEL docs https://fedoraproject.org/wiki/EPEL
        case os_info['name']
        when 'RedHat','CentOS','AlmaLinux','Rocky'
          install_latest_package_on(
            sut,
            'epel-release',
            "https://dl.fedoraproject.org/pub/epel/epel-release-latest-#{os_maj_rel}.noarch.rpm",
          )

          if os_info['name'] == 'RedHat' && ENV['BEAKER_RHSM_USER'] && ENV['BEAKER_RHSM_PASS']
            if os_maj_rel == '7'
              on sut, %{subscription-manager repos --enable "rhel-*-extras-rpms"}
              on sut, %{subscription-manager repos --enable "rhel-ha-for-rhel-*-server-rpms"}
            end

            if os_maj_rel == '8'
              on sut, %{subscription-manager repos --enable "codeready-builder-for-rhel-8-#{os_info['architecture']}-rpms"}
            end
          end

          if ['CentOS','AlmaLinux','Rocky'].include?(os_info['name'])
            if os_maj_rel == '8'
              # 8.0 fallback
              install_latest_package_on(sut, 'dnf-plugins-core')
              on sut, %{dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled PowerTools}
            end
          end
        when 'OracleLinux'
          package_name = "oracle-epel-release-el#{os_maj_rel}"
          install_latest_package_on(sut,package_name)
        when 'Amazon'
          on sut, %{amazon-linux-extras install epel -y}
        end
      end
    end
  end

  def update_package_from_centos_stream(suts, package_name)
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      sut.install_package('centos-release-stream') unless sut.check_for_package('centos-release-stream')
      install_latest_package_on(sut, package_name)
      sut.uninstall_package('centos-release-stream')
    end
  end

  def linux_errata( suts )
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      # Set the locale if not set
      sut.set_env_var('LANG', 'en_US.UTF-8') unless sut.get_env_var('LANG')

      # We need to be able to flip between server and client without issue
      on sut, 'puppet resource group puppet gid=52'
      on sut, 'puppet resource user puppet comment="Puppet" gid="52" uid="52" home="/var/lib/puppet" managehome=true'

      os_info = fact_on(sut, 'os')

      # Make sure we have a domain on our host
      current_domain = fact_on(sut, 'networking.domain')&.strip
      hostname = fact_on(sut, 'networking.hostname').strip

      if current_domain.nil? || current_domain.empty?
        new_fqdn = hostname + '.beaker.test'

        safe_sed(sut, 's/#{hostname}.*/#{new_fqdn} #{hostname}/', '/etc/hosts')

        if !sut.which('hostnamectl').empty?
          on(sut, "hostnamectl set-hostname #{new_fqdn}")
        else
          on(sut, "echo '#{new_fqdn}' > /etc/hostname", :accept_all_exit_codes => true)
          on(sut, "hostname #{new_fqdn}", :accept_all_exit_codes => true)
        end

        if sut.file_exist?('/etc/sysconfig/network')
          on(sut, "sed -s '/HOSTNAME=/d' /etc/sysconfig/network")
          on(sut, "echo 'HOSTNAME=#{new_fqdn}' >> /etc/sysconfig/network")
        end
      end

      current_domain = fact_on(sut, 'networking.domain')&.strip
      fail("Error: hosts must have an FQDN, got domain='#{current_domain}'") if current_domain.nil? || current_domain.empty?

      # This may not exist in docker so just skip the whole thing
      if sut.file_exist?('/etc/ssh')
        # SIMP uses a central ssh key location so we prep that spot in case we
        # flip to the SIMP SSH module.
        on(sut, 'mkdir -p /etc/ssh/local_keys')
        on(sut, 'chown -R root:root /etc/ssh/local_keys')
        on(sut, 'chmod 755 /etc/ssh/local_keys')

        user_info = on(sut, 'getent passwd').stdout.lines

        # Hash of user => home_dir
        # Exclude silly directories
        #   * /
        #   * /dev/*
        #   * /s?bin
        #   * /proc
        user_info = Hash[
          user_info.map do |u|
            u.strip!
            u = u.split(':')
            u[5] =~ %r{^(/|/dev/.*|/s?bin/?.*|/proc/?.*)$} ? [nil] : [u[0], u[5]]
          end
        ]

        user_info.keys.each do |user|
          src_file = "#{user_info[user]}/.ssh/authorized_keys"
          tgt_file = "/etc/ssh/local_keys/#{user}"

          on(sut, %{if [ -f "#{src_file}" ]; then cp -a -f "#{src_file}" "#{tgt_file}" && chmod 644 "#{tgt_file}"; fi}, :silent => true)
        end
      end

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

      if os_info['family'] == 'RedHat'
        # OS-specific items
        if os_info['name'] == 'RedHat'
          rhel_rhsm_subscribe(sut)

          RSpec.configure do |c|
            c.after(:all) do
              unless ENV['BEAKER_RHSM_UNSUBSCRIBE'] == 'false'
                rhel_rhsm_unsubscribe(sut)
              end
            end
          end
        end

        if [
            'AlmaLinux',
            'Amazon',
            'CentOS',
            'OracleLinux',
            'RedHat',
            'Rocky'
        ].include?(os_info['name'])
          enable_yum_repos_on(sut)
          enable_epel_on(sut)

          # net-tools required for netstat utility being used by be_listening
          if (os_info['release']['major'].to_i >= 7) ||((os_info['name'] == 'Amazon') && (os_info['release']['major'].to_i >= 2))
            pp = <<-EOS
              package { 'net-tools': ensure => installed }
            EOS
            apply_manifest_on(sut, pp, :catch_failures => false)
          end

          # Clean up YUM prior to starting our test runs.
          on(sut, 'yum clean all')
        end
      end
    end
  end

  # Register a RHEL system with a development license
  #
  # Must set BEAKER_RHSM_USER and BEAKER_RHSM_PASS environment variables or pass them in as
  # parameters
  def rhel_rhsm_subscribe(suts, *opts)
    require 'securerandom'

    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      rhsm_opts = {
        :username => ENV['BEAKER_RHSM_USER'],
        :password => ENV['BEAKER_RHSM_PASS'],
        :system_name => "#{sut}_beaker_#{Time.now.to_i}_#{SecureRandom.uuid}",
        :repo_list => {
          '7' => [
            'rhel-7-server-extras-rpms',
            'rhel-7-server-rh-common-rpms',
            'rhel-7-server-rpms',
            'rhel-7-server-supplementary-rpms'
          ],
          '8' => [
            'rhel-8-for-x86_64-baseos-rpms',
            'rhel-8-for-x86_64-supplementary-rpms'
          ],
          '9' => [
            'rhel-9-for-x86_64-appstream-rpms',
            'rhel-9-for-x86_64-baseos-rpms'
          ]
        }
      }

      if opts && opts.is_a?(Hash)
        rhsm_opts.merge!(opts)
      end

      os = fact_on(sut, 'os.name').strip
      os_release = fact_on(sut, 'os.release.major').strip

      if os == 'RedHat'
        unless rhsm_opts[:username] && rhsm_opts[:password]
          warn("BEAKER_RHSM_USER and/or BEAKER_RHSM_PASS not set on RHEL system.", "Assuming that subscription-manager is not needed. This may prevent packages from installing")
          return
        end

        sub_status = on(sut, 'subscription-manager status', :accept_all_exit_codes => true)
        unless sub_status.exit_code == 0
          logger.info("Registering #{sut} via subscription-manager")
          on(sut, %{subscription-manager register --auto-attach --name='#{rhsm_opts[:system_name]}' --username='#{rhsm_opts[:username]}' --password='#{rhsm_opts[:password]}'}, :silent => true)
        end

        if rhsm_opts[:repo_list][os_release]
          rhel_repo_enable(sut, rhsm_opts[:repo_list][os_release])
        else
          logger.warn("simp-beaker-helpers:#{__method__} => Default repos for RHEL '#{os_release}' not found")
        end

        # Ensure that all users can access the entitlements since we don't know
        # who we'll be running jobs as (often not root)
        on(sut, 'chmod -R ugo+rX /etc/pki/entitlement', :accept_all_exit_codes => true)
      end
    end
  end

  def sosreport(suts, dest='sosreports')
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      install_latest_package_on(sut, 'sos')
      on(sut, 'sosreport --batch')

      files = on(sut, 'ls /var/tmp/sosreport* /tmp/sosreport* 2>/dev/null', :accept_all_exit_codes => true).output.lines.map(&:strip)

      FileUtils.mkdir_p(dest)

      files.each do |file|
        scp_from(sut, file, File.absolute_path(dest))
      end
    end
  end

  def rhel_repo_enable(suts, repos)
    if ENV['BEAKER_RHSM_USER'] && ENV['BEAKER_RHSM_PASS']
      block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
        Array(repos).each do |repo|
          on(sut, %{subscription-manager repos --enable #{repo}})
        end
      end
    end
  end

  def rhel_repo_disable(suts, repos)
    if ENV['BEAKER_RHSM_USER'] && ENV['BEAKER_RHSM_PASS']
      block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
        Array(repos).each do |repo|
          on(sut, %{subscription-manager repos --disable #{repo}}, :accept_all_exit_codes => true)
        end
      end
    end
  end

  def rhel_rhsm_unsubscribe(suts)
    if ENV['BEAKER_RHSM_USER'] && ENV['BEAKER_RHSM_PASS']
      block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
        on(sut, %{subscription-manager unregister}, :accept_all_exit_codes => true)
      end
    end
  end

  # Apply known OS fixes we need to run Beaker on each SUT
  def fix_errata_on( suts = hosts )
    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      if is_windows?(sut)
        # Load the Windows requirements
        require 'simp/beaker_helpers/windows'

        # Install the necessary windows certificate for testing
        #
        # https://petersouter.xyz/testing-windows-with-beaker-without-cygwin/
        geotrust_global_ca = <<~EOM.freeze
        -----BEGIN CERTIFICATE-----
        MIIDVDCCAjygAwIBAgIDAjRWMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT
        MRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i
        YWwgQ0EwHhcNMDIwNTIxMDQwMDAwWhcNMjIwNTIxMDQwMDAwWjBCMQswCQYDVQQG
        EwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UEAxMSR2VvVHJ1c3Qg
        R2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2swYYzD9
        9BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9mOSm9BXiLnTjoBbdq
        fnGk5sRgprDvgOSJKA+eJdbtg/OtppHHmMlCGDUUna2YRpIuT8rxh0PBFpVXLVDv
        iS2Aelet8u5fa9IAjbkU+BQVNdnARqN7csiRv8lVK83Qlz6cJmTM386DGXHKTubU
        1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmRCw7+OC7RHQWa9k0+
        bw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5aszPeE4uwc2hGKceeoW
        MPRfwCvocWvk+QIDAQABo1MwUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTA
        ephojYn7qwVkDBF9qn1luMrMTjAfBgNVHSMEGDAWgBTAephojYn7qwVkDBF9qn1l
        uMrMTjANBgkqhkiG9w0BAQUFAAOCAQEANeMpauUvXVSOKVCUn5kaFOSPeCpilKIn
        Z57QzxpeR+nBsqTP3UEaBU6bS+5Kb1VSsyShNwrrZHYqLizz/Tt1kL/6cdjHPTfS
        tQWVYrmm3ok9Nns4d0iXrKYgjy6myQzCsplFAMfOEVEiIuCl6rYVSAlk6l5PdPcF
        PseKUgzbFbS9bZvlxrFUaKnjaZC2mqUPuLk/IH2uSrW4nOQdtqvmlKXBx4Ot2/Un
        hw4EbNX/3aBd7YdStysVAq45pmp06drE57xNNB6pXE0zX5IJL4hmXXeXxx12E6nV
        5fEWCRE11azbJHFwLJhWC9kXtNHjUStedejV0NxPNO3CBWaAocvmMw==
        -----END CERTIFICATE-----
        EOM

        install_cert_on_windows(sut, 'geotrustglobal', geotrust_global_ca)
      else
        linux_errata(sut)
      end
    end

    # Configure and reboot SUTs into FIPS mode
    if ENV['BEAKER_fips'] == 'yes'
      enable_fips_mode_on(suts)
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

    ca_sut.mkdir_p(host_dir)
    Dir[ File.join(pki_dir, '*') ].each{|f| copy_to( ca_sut, f, host_dir)}

    # Collect network information from all SUTs
    #
    # We need this so that we don't insert any common IP addresses into certs
    suts_network_info = {}

    hosts.each do |host|
      fqdn = fact_on(host, 'networking.fqdn').strip

      host_entry = { fqdn => [] }

      # Add the short name because containers can't change the hostname
      host_entry[fqdn] << host.name if (host[:hypervisor] == 'docker')

      # Ensure that all interfaces are active prior to collecting data
      activate_interfaces(host)

      networking_fact = pfact_on(host, 'networking')
      if networking_fact && networking_fact['interfaces']
        networking_fact['interfaces'].each do |iface, data|
          next unless data['ip']
          next if data['ip'].start_with?('127.')

          host_entry[fqdn] << data['ip'].strip
        end
      else
        # Gather the IP Addresses for the host to embed in the cert
        interfaces = fact_on(host, 'interfaces').strip.split(',')
        interfaces.each do |interface|
          ipaddress = fact_on(host, "ipaddress_#{interface}")

          next if ipaddress.nil? || ipaddress.empty? || ipaddress.start_with?('127.')

          host_entry[fqdn] << ipaddress.strip
        end
      end

      unless host_entry[fqdn].empty?
        suts_network_info[fqdn] = host_entry[fqdn].sort.uniq
      end
    end

    # Get all of the repeated SUT IP addresses:
    #   1. Create a hash of elements that have a key that is the value and
    #      elements that are the same value
    #   2. Grab all elements that have more than one value (therefore, were
    #      repeated)
    #   3. Pull out an Array of all of the common element keys for future
    #      comparison
    common_ip_addresses = suts_network_info
      .values.flatten
      .group_by{ |x| x }
      .select{|k,v| v.size > 1}
      .keys

    # generate PKI certs for each SUT
    Dir.mktmpdir do |dir|
      pki_hosts_file = File.join(dir, 'pki.hosts')

      File.open(pki_hosts_file, 'w') do |fh|
        suts_network_info.each do |fqdn, ipaddresses|
          fh.puts ([fqdn] + (ipaddresses - common_ip_addresses)) .join(',')
        end
      end

      copy_to(ca_sut, pki_hosts_file, host_dir)

      # generate certs
      on(ca_sut, "cd #{host_dir}; cat #{host_dir}/pki.hosts | xargs bash make.sh")
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
  #                 # This is a copy of cacerts.pem since cacerts.pem is a
  #                 # collection of the CA certificates in pupmod-simp-pki
  #                 cacerts/simp_auto_ca.pem
  #                 public/fdqn.pub
  #                 private/fdqn.pem
  def copy_pki_to(sut, local_pki_dir, sut_base_dir = '/etc/pki/simp-testing')
      fqdn                = fact_on(sut, 'networking.fqdn')
      sut_pki_dir         = File.join( sut_base_dir, 'pki' )
      local_host_pki_tree = File.join(local_pki_dir,'pki','keydist',fqdn)
      local_cacert = File.join(local_pki_dir,'pki','demoCA','cacert.pem')

      sut.mkdir_p("#{sut_pki_dir}/public")
      sut.mkdir_p("#{sut_pki_dir}/private")
      sut.mkdir_p("#{sut_pki_dir}/cacerts")
      copy_to(sut, "#{local_host_pki_tree}/#{fqdn}.pem", "#{sut_pki_dir}/private/")
      copy_to(sut, "#{local_host_pki_tree}/#{fqdn}.pub", "#{sut_pki_dir}/public/")

      copy_to(sut, local_cacert, "#{sut_pki_dir}/cacerts/simp_auto_ca.pem")

      # NOTE: to match pki::copy, 'cacert.pem' is copied to 'cacerts.pem'
      copy_to(sut, local_cacert, "#{sut_pki_dir}/cacerts/cacerts.pem")

      # Need to hash all of the CA certificates so that apps can use them
      # properly! This must happen on the host itself since it needs to match
      # the native hashing algorithms.
      hash_cmd = <<~EOM.strip
        PATH=/opt/puppetlabs/puppet/bin:$PATH; \
        cd #{sut_pki_dir}/cacerts; \
        for x in *; do \
          if [ ! -h "$x" ]; then \
            `openssl x509 -in $x >/dev/null 2>&1`; \
            if [ $? -eq 0 ]; then \
              hash=`openssl x509 -in $x -hash | head -1`; \
              ln -sf $x $hash.0; \
            fi; \
           fi; \
        done
        EOM

      on(sut, hash_cmd)
  end

  # Copy a CA keydist/ directory of CA+host certs into an SUT
  #
  # This simulates the output of FakeCA's gencerts_nopass.sh to keydist/
  def copy_keydist_to( ca_sut = master, host_keydist_dir = nil  )
    if !host_keydist_dir
      modulepath = puppet_modulepath_on(ca_sut)

      host_keydist_dir = "#{modulepath.first}/pki/files/keydist"
    end
    on ca_sut, "rm -rf #{host_keydist_dir}/*"
    ca_sut.mkdir_p(host_keydist_dir)
    on ca_sut, "cp -pR /root/pki/keydist/. #{host_keydist_dir}/"
    on ca_sut, "chgrp -R puppet #{host_keydist_dir}"
  end

  # Activate all network interfaces on the target system
  #
  # This is generally needed if the upstream vendor does not activate all
  # interfaces by default (EL7 for example)
  #
  # Can be passed any number of hosts either singly or as an Array
  def activate_interfaces(hosts)
    return if ENV['BEAKER_no_fix_interfaces']

    block_on(hosts, :run_in_parallel => @run_in_parallel) do |host|
      if host[:platform] =~ /windows/
        puts "  -- SKIPPING #{host} because it is windows"
        next
      end

      networking_fact = pfact_on(host, 'networking')
      if networking_fact && networking_fact['interfaces']
        networking_fact['interfaces'].each do |iface, data|
          next if ( ( data['ip'] && !data['ip'].empty? ) || ( data['ip6'] && !data['ip6'].empty? ) )
          on(host, "ifup #{iface}", :accept_all_exit_codes => true)
        end
      else
        interfaces_fact = pfact_on(host, 'interfaces')

        interfaces = interfaces_fact.strip.split(',')
        interfaces.delete_if { |x| x =~ /^lo/ }

        interfaces.each do |iface|
          if pfact_on(host, "ipaddress_#{iface}")
            on(host, "ifup #{iface}", :accept_all_exit_codes => true)
          end
        end
      end
    end
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

      # We can't guarantee that the upstream vendor isn't disabling interfaces
      activate_interfaces(hosts)
    end

    c.after(:all) do
      clear_temp_hieradata
    end
  end

  # Return the contents of a file on the remote host
  #
  # @param sut [Host] the host upon which to operate
  # @param path [String] the path to the target file
  # @param trim [Boolean] remove leading and trailing whitespace
  #
  # @return [String, nil] the contents of the remote file
  def file_content_on(sut, path, trim=true)
    file_content = nil

    if file_exists_on(sut, path)
      Dir.mktmpdir do |dir|
        scp_from(sut, path, dir)

        file_content = File.read(File.join(dir,File.basename(path)))
      end
    end

    return file_content
  end

  # Retrieve the default hiera.yaml path
  #
  # @param sut [Host] one host to act upon
  #
  # @returns [Hash] path to the default environment's hiera.yaml
  def hiera_config_path_on(sut)
    File.join(puppet_environment_path_on(sut), 'hiera.yaml')
  end

  # Retrieve the default environment hiera.yaml
  #
  # @param sut [Host] one host to act upon
  #
  # @returns [Hash] content of the default environment's hiera.yaml
  def get_hiera_config_on(sut)
    file_content_on(sut, hiera_config_path_on(sut))
  end

  # Updates the default environment hiera.yaml
  #
  # @param sut [Host] One host to act upon
  # @param hiera_yaml [Hash, String] The data to place into hiera.yaml
  #
  # @returns [void]
  def set_hiera_config_on(sut, hiera_yaml)
    hiera_yaml = hiera_yaml.to_yaml if hiera_yaml.is_a?(Hash)

    create_remote_file(sut, hiera_config_path_on(sut), hiera_yaml)
  end

  # Writes a YAML file in the Hiera :datadir of a Beaker::Host.
  #
  # @note This is useless unless Hiera is configured to use the data file.
  #   @see `#set_hiera_config_on`
  #
  # @param sut  [Array<Host>, String, Symbol] One or more hosts to act upon.
  #
  # @param hieradata [Hash, String] The full hiera data structure to write to
  #   the system.
  #
  # @param terminus [String]  DEPRECATED - This will be removed in a future
  #   release and currently has no effect.
  #
  # @return [Nil]
  #
  # @note This creates a tempdir on the host machine which should be removed
  #   using `#clear_temp_hieradata` in the `after(:all)` hook.  It may also be
  #   retained for debugging purposes.
  #
  def write_hieradata_to(sut, hieradata, terminus = 'deprecated')
    @temp_hieradata_dirs ||= []
    data_dir = Dir.mktmpdir('hieradata')
    @temp_hieradata_dirs << data_dir

    fh = File.open(File.join(data_dir, 'common.yaml'), 'w')
    if hieradata.is_a?(String)
      fh.puts(hieradata)
    else
      fh.puts(hieradata.to_yaml)
    end
    fh.close

    copy_hiera_data_to sut, File.join(data_dir, 'common.yaml')
  end

  # A shim to stand in for the now deprecated copy_hiera_data_to function
  #
  # @param sut [Host]  One host to act upon
  #
  # @param [Path] File containing hiera data
  def copy_hiera_data_to(sut, path)
    copy_to(sut, path, hiera_datadir(sut))
  end

  # A shim to stand in for the now deprecated hiera_datadir function
  #
  # Note: This may not work if you've shoved data somewhere that is not the
  # default and/or are manipulating the default hiera.yaml.
  #
  # @param sut [Host] One host to act upon
  #
  # @returns [String] Path to the Hieradata directory on the target system
  def hiera_datadir(sut)
    # A workaround for PUP-11042
    sut_environment = sut.puppet_configprint['environment']

    # This output lets us know where Hiera is configured to look on the system
    puppet_lookup_info = on(sut, "puppet lookup --explain --environment #{sut_environment} test__simp__test", :silent => true).output.strip.lines

    if sut.puppet_configprint['manifest'].nil? || sut.puppet_configprint['manifest'].empty?
      fail("No output returned from `puppet config print manifest` on #{sut}")
    end

    puppet_env_path = puppet_environment_path_on(sut)

    # We'll just take the first match since Hiera will find things there
    puppet_lookup_info = puppet_lookup_info.grep(/Path "/).grep(Regexp.new(puppet_env_path))

    # Grep always returns an Array
    if puppet_lookup_info.empty?
      fail("Could not determine hiera data directory under #{puppet_env_path} on #{sut}")
    end

    # Snag the actual path without the extra bits
    puppet_lookup_info = puppet_lookup_info.first.strip.split('"').last

    # Make the parent directories exist
    sut.mkdir_p(File.dirname(puppet_lookup_info))

    # We just want the data directory name
    datadir_name = puppet_lookup_info.split(puppet_env_path).last

    # Grab the file separator to add back later
    file_sep = datadir_name[0]

    # Snag the first entry (this is the data directory)
    datadir_name = datadir_name.split(file_sep)[1]

    # Constitute the full path to the data directory
    datadir_path = puppet_env_path + file_sep + datadir_name

    # Return the path to the data directory
    return datadir_path
  end

  # Write the provided data structure to Hiera's :datadir and configure Hiera to
  # use that data exclusively.
  #
  # @note This is authoritative.  It manages both Hiera data and configuration,
  #   so it may not be used with other Hiera data sources.
  #
  # @param sut  [Array<Host>, String, Symbol] One or more hosts to act upon.
  #
  # @param heradata [Hash, String] The full hiera data structure to write to
  #   the system.
  #
  # @param terminus [String] DEPRECATED - Will be removed in a future release.
  #        All hieradata is written to the first discovered path via 'puppet
  #        lookup'
  #
  # @return [Nil]
  #
  def set_hieradata_on(sut, hieradata, terminus = 'deprecated')
    write_hieradata_to sut, hieradata
  end


  # Clean up all temporary hiera data files.
  #
  # Meant to be called from after(:all)
  def clear_temp_hieradata
    if @temp_hieradata_dirs && !@temp_hieradata_dirs.empty?
      @temp_hieradata_dirs.each do |data_dir|
        if File.exist?(data_dir)
          FileUtils.rm_r(data_dir)
        end
      end
    end
  end


  # pluginsync custom facts for all modules
  def pluginsync_on( suts = hosts )
    puts "== pluginsync_on'" if ENV['BEAKER_helpers_verbose']
    pluginsync_manifest =<<-PLUGINSYNC_MANIFEST
    file { $::settings::libdir:
          ensure  => directory,
          source  => 'puppet:///plugins',
          recurse => true,
          purge   => true,
          backup  => false,
          noop    => false
        }
    PLUGINSYNC_MANIFEST
    apply_manifest_on(hosts, pluginsync_manifest, :run_in_parallel => @run_in_parallel)
  end


  # Looks up latest `puppet-agent` version by the version of its `puppet` gem
  #
  # @param puppet_version [String] target Puppet gem version.  Works with
  #   Gemfile comparison syntax (e.g., '4.0', '= 4.2', '~> 4.3.1', '> 5.1, < 5.5')
  #
  # @return [String,Nil] the `puppet-agent` version or nil
  #
  def latest_puppet_agent_version_for( puppet_version )
    return nil if puppet_version.nil?

    require 'rubygems/requirement'
    require 'rubygems/version'
    require 'yaml'

    _puppet_version = puppet_version.strip.split(',')


    @agent_version_table ||= YAML.load_file(
                               File.expand_path(
                                 '../../files/puppet-agent-versions.yaml',
                                 File.dirname(__FILE__)
                             )).fetch('version_mappings')
    _pair = @agent_version_table.find do |k,v|
      Gem::Requirement.new(_puppet_version).satisfied_by?(Gem::Version.new(k))
    end
    result = _pair ? _pair.last : nil

    # If we didn't get a match, go look for published rubygems
    unless result
      puppet_gems = nil

      Bundler.with_unbundled_env do
        puppet_gems = %x(gem search -ra -e puppet).match(/\((.+)\)/)
      end

      if puppet_gems
        puppet_gems = puppet_gems[1].split(/,?\s+/).select{|x| x =~ /^\d/}

        # If we don't have a full version string, we need to massage it for the
        # match.
        begin
          if _puppet_version.size == 1
            Gem::Version.new(_puppet_version[0])
            if _puppet_version[0].count('.') < 2
             _puppet_version = "~> #{_puppet_version[0]}"
            end
          end
        rescue ArgumentError
          # this means _puppet_version is not just a version, but a version
          # specifier such as "= 5.2.3", "<= 5.1", "> 4", "~> 4.10.7"
        end

        result = puppet_gems.find do |ver|
          Gem::Requirement.new(_puppet_version).satisfied_by?(Gem::Version.new(ver))
        end
      end
    end

    return result
  end

  # returns hash with :puppet_install_version, :puppet_collection,
  # and :puppet_install_type keys determined from environment variables,
  # host settings, and/or defaults
  #
  # NOTE: BEAKER_PUPPET_AGENT_VERSION or PUPPET_INSTALL_VERSION or
  #       PUPPET_VERSION takes precedence over BEAKER_PUPPET_COLLECTION
  #       or host.options['puppet_collection'], when both a puppet
  #       install version and a puppet collection are specified. This is
  #       because the puppet install version can specify more precise
  #       version information than is available from a puppet collection.
  def get_puppet_install_info
    # The first match is internal Beaker and the second is legacy SIMP
    puppet_install_version = ENV['BEAKER_PUPPET_AGENT_VERSION'] || ENV['PUPPET_INSTALL_VERSION'] || ENV['PUPPET_VERSION']

    if puppet_install_version and !puppet_install_version.strip.empty?
      puppet_agent_version = latest_puppet_agent_version_for(puppet_install_version.strip)
    end

    if puppet_agent_version.nil?
      if puppet_collection = (ENV['BEAKER_PUPPET_COLLECTION'] || host.options['puppet_collection'])
        if puppet_collection =~ /puppet(\d+)/
          puppet_install_version = "~> #{$1}"
          puppet_agent_version = latest_puppet_agent_version_for(puppet_install_version)
        else
          raise("Error: Puppet Collection '#{puppet_collection}' must match /puppet(\\d+)/")
        end
      else
        puppet_agent_version = latest_puppet_agent_version_for(DEFAULT_PUPPET_AGENT_VERSION)
      end
    end

    if puppet_collection.nil?
      base_version = puppet_agent_version.to_i
      puppet_collection = "puppet#{base_version}" if base_version >= 5
    end

    {
      :puppet_install_version => puppet_agent_version,
      :puppet_collection      => puppet_collection,
      :puppet_install_type    => ENV.fetch('PUPPET_INSTALL_TYPE', 'agent')
    }
  end


  # Replacement for `install_puppet` in spec_helper_acceptance.rb
  def install_puppet
    install_info = get_puppet_install_info

    # In case  Beaker needs this info internally
    ENV['PUPPET_INSTALL_VERSION'] = install_info[:puppet_install_version]
    if install_info[:puppet_collection]
      ENV['BEAKER_PUPPET_COLLECTION'] = install_info[:puppet_collection]
    end

    require 'beaker-puppet'
    install_puppet_on(hosts, version: install_info[:puppet_install_version])
  end

  # Configure all SIMP repos on a host and disable all repos in the disable Array
  #
  # @param sut [Beaker::Host]  Host on which to configure SIMP repos
  # @param disable [Array[String]] List of repos to disable
  # @raise [StandardError] if disable contains an invalid repo name.
  #
  # Examples:
  #  install_simp_repos( myhost )           # install all the repos an enable them.
  #  install_simp_repos( myhost, ['simp'])  # install the repos but disable the simp repo.
  #
  # Valid repo names include any repository available on the system.
  #
  # For backwards compatibility purposes, the following translations are
  # automatically performed:
  #
  #  * 'simp'
  #    * 'simp-community-simp'
  #
  #  * 'simp_deps'
  #    * 'simp-community-epel'
  #    * 'simp-community-postgres'
  #    * 'simp-community-puppet'
  #
  #
  # Environment Variables:
  #   * BEAKER_SIMP_install_repos
  #     * 'no' => disable the capability
  #   * BEAKER_SIMP_disable_repos
  #     * Comma delimited list of active yum repo names to disable
  def install_simp_repos(suts, disable = [])
    # NOTE: Do *NOT* use puppet in this method since it may not be available yet

    return if (ENV.fetch('SIMP_install_repos', 'yes') == 'no')

    block_on(suts, :run_in_parallel => @run_in_parallel) do |sut|
      install_package_unless_present_on(sut, 'yum-utils')

      os = fact_on(sut, 'os.name')
      release = fact_on(sut, 'os.release.major')

      # Work around Amazon 2 compatibility
      if (( os == 'Amazon' ) && ( "#{release}" == '2' ))
        release = '7'
      end

      install_package_unless_present_on(
        sut,
        'simp-release-community',
        "https://download.simp-project.com/simp-release-community.el#{release}.rpm"
      )

      # TODO: Remove this hack-around when there's a version for AL2
      if ( os == 'Amazon' )
        on(sut, %(sed -i 's/$releasever/#{release}/g' /etc/yum.repos.d/simp*))
      end

      to_disable = disable.dup
      to_disable += ENV.fetch('BEAKER_SIMP_disable_repos', '').split(',').map(&:strip)

      unless to_disable.empty?
        if to_disable.include?('simp') || to_disable.include?('simp-community-simp')
          to_disable.delete('simp')

          # legacy community RPM
          to_disable << 'simp-community-simp'

          # SIMP 6.6+ community RPM
          to_disable << 'SIMP--simp'
        end

        if to_disable.include?('simp_deps')
          to_disable.delete('simp_deps')
          # legacy community RPM
          to_disable << 'simp-community-epel'
          to_disable << 'simp-community-postgres'
          to_disable << 'simp-community-puppet'

          # SIMP 6.6+ community RPM
          to_disable << 'epel--simp'
          to_disable << 'postgresql--simp'
          to_disable << 'puppet--simp'
          to_disable << 'puppet7--simp'
          to_disable << 'puppet6--simp'
        end

        logger.info(%{INFO: repos to disable: '#{to_disable.join("', '")}'.})

        # NOTE: This --enablerepo enables the repos for listing and is inherited
        # from YUM. This does not actually "enable" the repos, that would require
        # the "--enable" option (from yum-config-manager) :-D.
        #
        # Note: Certain versions of EL8 do not dump by default and EL7 does not
        # have the '--dump' option.
        x = on(sut, %{yum repolist all || dnf repolist --all}).stdout.lines
        y = x.map{|z| z.gsub(%r{/.*\Z},'')}
        available_repos = y.grep(/\A([a-zA-Z][a-zA-Z0-9:_-]+)\s*/){|x| $1}
        logger.info(%{INFO: available repos: '#{available_repos.join("', '")}'.})

        invalid_repos = (to_disable - available_repos)

        # Verify that the repos passed to disable are in the list of valid repos
        unless invalid_repos.empty?
          logger.warn(%{WARN: install_simp_repo - requested repos to disable do not exist on the target system '#{invalid_repos.join("', '")}'.})
        end


        (to_disable - invalid_repos).each do |repo|
          on(sut, %{yum-config-manager --disable "#{repo}"})
        end
      end
    end

    set_yum_opts_on(suts, {'simp*.skip_if_unavailable' => '1' })
  end

  # Set the release and release type of the SIMP yum repos
  #
  # Environment variables may be used to set either one
  #   * BEAKER_SIMP_repo_release => The actual release (version number)
  #   * BEAKER_SIMP_repo_release_type => The type of release (stable, unstable, rolling, etc...)
  def set_simp_repo_release(sut, simp_release_type='stable', simp_release='6')
    simp_release = ENV.fetch('BEAKER_SIMP_repo_release', simp_release)
    simp_release_type = ENV.fetch('BEAKER_SIMP_repo_release_type', simp_release_type)

    simp_release_type = 'releases' if (simp_release_type == 'stable')

    create_remote_file(sut, '/etc/yum/vars/simprelease', simp_release)
    create_remote_file(sut, '/etc/yum/vars/simpreleasetype', simp_release_type)
  end
end
