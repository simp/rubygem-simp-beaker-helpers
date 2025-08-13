# SIMP namespace
module Simp; end

# SIMP Beaker helper methods for testing
module Simp::BeakerHelpers
  # Extracted from beaker-puppet

  # The directories in the module directory that will not be scp-ed to the test system when using
  # `copy_module_to`
  PUPPET_MODULE_INSTALL_IGNORE = ['/.bundle', '/.git', '/.idea', '/.vagrant', '/.vendor', '/vendor', '/acceptance',
                                  '/bundle', '/spec', '/tests', '/log', '/.svn', '/junit', '/pkg', '/example', '/tmp',].freeze

  # Here be the pathing and default values for AIO installs
  #
  AIO_DEFAULTS = {
    'unix' => {
      'puppetbindir' => '/opt/puppetlabs/bin',
      'privatebindir' => '/opt/puppetlabs/puppet/bin',
      'distmoduledir' => '/etc/puppetlabs/code/modules',
      'sitemoduledir' => '/opt/puppetlabs/puppet/modules',
    },
    # sitemoduledir not included on Windows (check PUP-4049 for more info).
    #
    # Paths to the puppet's vendored ruby installation on Windows were
    # updated in Puppet 6 to more closely match those of *nix agents.
    # These path values include both the older (puppet <= 5) paths (which
    # include sys/ruby) and the newer versions, which have no custom ruby
    # directory
    'windows' => { # windows with cygwin
      'puppetbindir' => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin',
      'privatebindir' => '/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/puppet/bin:/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/sys/ruby/bin',
      'distmoduledir' => '`cygpath -smF 35`/PuppetLabs/code/modules',
    },
    'windows-64' => { # windows with cygwin
      'puppetbindir' => '/cygdrive/c/Program Files/Puppet Labs/Puppet/bin',
      'privatebindir' => '/cygdrive/c/Program Files/Puppet Labs/Puppet/puppet/bin:/cygdrive/c/Program Files/Puppet Labs/Puppet/sys/ruby/bin',
      'distmoduledir' => '`cygpath -smF 35`/PuppetLabs/code/modules',
    },
    'pswindows' => { # pure windows
      'puppetbindir' => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\bin";"C:\\Program Files\\Puppet Labs\\Puppet\\bin"',
      'privatebindir' => '"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\puppet\\bin";"C:\\Program Files\\Puppet Labs\\Puppet\\puppet\\bin";"C:\\Program Files (x86)\\Puppet Labs\\Puppet\\sys\\ruby\\bin";"C:\\Program Files\\Puppet Labs\\Puppet\\sys\\ruby\\bin"',
      'distmoduledir' => 'C:\\ProgramData\\PuppetLabs\\code\\modules',
    },
  }.freeze

  # Given a host construct a PATH that includes puppetbindir, facterbindir and hierabindir
  # @param [Host] host    A single host to construct pathing for
  def construct_puppet_path(host)
    path = %w[puppetbindir facterbindir hierabindir privatebindir].compact.reject(&:empty?)
    # get the PATH defaults
    path.map! { |val| host[val] }
    path = path.compact.reject(&:empty?)
    # run the paths through echo to see if they have any subcommands that need processing
    path.map! { |val| echo_on(host, val) }

    separator = host['pathseparator']
    separator = ':' unless host.is_powershell?
    path.join(separator)
  end

  # Append puppetbindir, facterbindir and hierabindir to the PATH for each host
  # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
  #                            or a role (String or Symbol) that identifies one or more hosts.
  def add_puppet_paths_on(hosts)
    block_on hosts do |host|
      puppet_path = construct_puppet_path(host)
      host.add_env_var('PATH', puppet_path)
    end
  end

  # Add the appropriate aio defaults to the host object so that they can be accessed using host[option], set host[:type] = aio
  # @param [Host] host    A single host to act upon
  # @param [String] platform The platform type of this host, one of 'windows', 'pswindows', or 'unix'
  def add_platform_aio_defaults(host, platform)
    AIO_DEFAULTS[platform].each_pair do |key, val|
      host[key] = val
    end
    # add group and type here for backwards compatability
    host['group'] = if host['platform'] =~ /windows/
                      'Administrators'
                    else
                      'puppet'
                    end
  end

  # Add the appropriate aio defaults to an array of hosts
  # @param [Host, Array<Host>, String, Symbol] hosts    One or more hosts to act upon,
  #                            or a role (String or Symbol) that identifies one or more hosts.
  def add_aio_defaults_on(hosts)
    block_on hosts do |host|
      if host.is_powershell?
        platform = 'pswindows'
      elsif host['platform'] =~ /windows/
        ruby_arch = if host[:ruby_arch] == 'x64'
                      /-64/
                    else
                      /-32/
                    end
        platform = if host['platform'] =~ ruby_arch
                     'windows-64'
                   else
                     'windows'
                   end
      else
        platform = 'unix'
      end
      add_platform_aio_defaults(host, platform)
    end
  end

  # Given a type return an understood host type
  # @param [String] type The host type to be normalized
  # @return [String] The normalized type
  #
  # @example
  #  normalize_type('pe-aio')
  #    'pe'
  # @example
  #  normalize_type('git')
  #    'foss'
  # @example
  #  normalize_type('foss-internal')
  #    'foss'
  def normalize_type(type)
    case type
    when /(\A|-)foss(\Z|-)/
      'foss'
    when /(\A|-)pe(\Z|-)/
      'pe'
    when /(\A|-)aio(\Z|-)/
      'aio'
    end
  end

  # Configure the provided hosts to be of their host[:type], it host[type] == nil do nothing
  def configure_type_defaults_on(hosts)
    block_on hosts do |host|
      has_defaults = false
      if host[:type]
        host_type = host[:type]
        # clean up the naming conventions here (some teams use foss-package, git-whatever, we need
        # to correctly handle that
        # don't worry about aio, that happens in the aio_version? check
        host_type = normalize_type(host_type)
        if host_type and host_type !~ /aio/
          add_method = "add_#{host_type}_defaults_on"
          raise "cannot add defaults of type #{host_type} for host #{host.name} (#{add_method} not present)" unless respond_to?(
            add_method, host
          )

          send(add_method, host)

          has_defaults = true
        end
      end
      if aio_version?(host)
        add_aio_defaults_on(host)
        has_defaults = true
      end
      # add pathing env
      add_puppet_paths_on(host) if has_defaults
    end
  end
end
