### 2.0.3 / 2025-10-07
* Fixed:
  * Removed outdated/incorrect errata for Windows machines (#261)

### 2.0.2 / 2025-08-12
* Fixed:
  * Updated dependencies to allow beaker >= 7.0.0 (#239)

### 2.0.1 / 2025-08-28
* Fixed:
  * Rename `fips_enabled` method to `fips_enabled?`
    to correct a rubocop complaint

### 2.0.0 / 2025-08-12
* Added
  * Openvox support (re-publishing 1.36.0 as a breaking change)

### 1.36.1 / 2025-08-12
* Fixed:
  * Reverted breaking change (#236)

### 1.36.0 / 2025-06-23
* Added
  * Openvox support

### 1.35.1 / 2025-06-11
* Fixed:
  * `TypeError: Rake is not a class` error (#231)

### 1.35.0 / 2024-12-19
* Fixed:
  * Clean up for rubocop

### 1.34.3 / 2024-12-20
* Fixed:
  * Update /etc/hosts on all nodes when hostname changes (#227)

### 1.34.2 / 2024-12-19
* Fixed:
  * Update /etc/hosts when hostname changes (#224)

### 1.34.1 / 2024-12-17
* Fixed:
  * Error when no domain is set (#222)

### 1.34.0 / 2024-09-17
* Fixed:
  * Legacy fact usage
* Added:
  * EL9 support in Simp::BeakerHelpers::SSG

### 1.33.0 / 2024-06-05
* Fixed:
  * Update gem dependencies

### 1.32.1 / 2023-08-28
* Fixed:
  * Version bump to resolve mis-tagging

### 1.32.0 / 2023-08-24
* Added:
  * Switch to Puppet 8 by default
* Fixed:
  * Update gem dependencies

### 1.31.0 / 2023-07-18
* Fixed:
  * Compatibility with Ruby 3.2

### 1.30.0 / 2023-05-15
* Added:
  * Default `puppet_collection` to `puppet7`
  * Support for new pulp-slimmed repo names in `install_simp_repos` logic
  * Modernize GHA PR test matrix
    * Support for experimental (Puppet 8.x/ruby 3.1)
  * Add GHA acceptance test matrix (puppet version x suite)
    * Support for experimental (Puppet 8.x/ruby 3.1)
    * Allow problematic inspec suite to fail
* Fixed:
  * Update to `beaker-rspec` 8.x depsolve with `simp-rake-helpers` 5.20.0+
  * Update `beaker` to permit 5.x
  * Update default `puppet-agent` to 7.x
  * Use less fragile yum/dnf `repolist` in `install_simp_repos` logic
* Removed
  * inspec acceptance suite no longer required in GHA matrix

### 1.29.0 / 2022-10-25
* Fixed:
  * Compress fixtures before copy to Windows nodes

### 1.28.0 / 2022-08-05
* Added:
  * Support RHEL versions without RHN credentials
    * Supports pay-as-you-go cloud services

### 1.27.0 / 2022-07-30
* Added:
  * Add EPEL support for Amazon, Rocky, and Alma distributions

### 1.26.2 / 2022-07-26
* Fixed:
  * Limit the length of the CN field of the certificates to 64 bytes

### 1.26.1 / 2022-06-24
* Fixed:
  * Ensure that `multi_node` is enabled by default for backwards compatibility
  * Sort the discovered nodesets by default when running with `ALL` nodesets

### 1.26.0 / 2022-06-24
* Added:
  * Allow for sequential nodesets by setting `multi_node: false` in the
    `CONFIG:` section of your nodeset.

### 1.25.0 / 2022-06-11
* Fixed:
  * Replaced calls to `sed -c` with something POSIX compliant that should work
    on non-RHEL systems
* Added:
  * Updated all dependencies to their latest versions where possible and removed
    dependencies on deprecated libraries.

### 1.24.5 / 2022-05-06
* Fixed:
  * Added a workaround for Amazon Linux 2 testing

### 1.24.4 / 2022-04-28
* Fixed:
  * Workaround for [MODULES-11315] in `puppet-agent-versions.yaml`
* Removed:
  * Dropped acceptance tests for Puppet 5.5

[MODULES-11315]: https://tickets.puppetlabs.com/browse/MODULES-11315

### 1.24.3 / 2022-04-10
* Fixed:
  * Added python-setuptools to the list of required packages

### 1.24.2 / 2022-03-09
* Fixed:
  * Prevent `spec/` directory symlink recursion in `copy_fixture_modules_to`
  * Update the derivatives workaround to insert an inert line instead of
    commenting out the previous line to allow for logic updates
  * Addressed a bug where passing an empty exceptions array would produce an
    invalid xpath query
  * Ensure that the new SIMP community RPMs are used

### 1.24.1 / 2021-10-27
* Fixed:
  * Worked around a bug in 'puppet lookup' - PUP-11402
  * Updated calls to the operating system fact when connecting to RHSM

### 1.24.0 / 2021-10-05
* Fixed:
  * Pinned the version of inspec to 4.39.0 since 4.41 broke tag processing
  * Only call `activate_interfaces` once per test run instead of at each context
    which saves quite a bit of time during testing
  * SSG tag selection logic
  * Use `sed -ci` which works with docker volume mounts
* Added:
  * Modified the `activate_interfaces` method to use the `networking` fact if
    available which shaves quite a bit of time off of each test run

### 1.23.4 / 2021-07-07
* Fixed:
  * Ensure that the openscap-scanner package is installed during SSG runs
* Added:
  * A function to fetch the available SSG profiles on a target system
* Changed:
  * Added OEL nodeset

### 1.23.3 / 2021-06-30
* Fixed:
  * Removed the Streams kernel update for EL 8.3 since it now causes issues
  * Use `pfact_on` to select the interface facts to fix Puppet 7 issues

### 1.23.2 / 2021-05-29
* Fixed:
  * Fail an acceptance test when an explicitly-specified nodeset for an
    acceptance test suite does not exist and the suite is configured
    to fail fast (default behavior).
  * The usual way of registering RHEL systems had to be changed to activate
    immediately when called to function properly.

### 1.23.1 / 2021-05-19
* Fixed:
  * The SSG default branch is now the latest numeric tag instead of the one
    closest to the head of the default branch. The tag closest to the default
    branch has drifted over time.
  * Removed direct call to `docker` when copying out inspec results
  * Typos in `copy_in` when running against docker
* Added:
  * `Simp::BeakerHelpers::Inspec.enable_repo_on(suts)` to allow users to easily
    enable the Chef repos for inspec
  * Beaker tests for inspec and SSG basic functionality
  * GitHub Actions for acceptance testing where possible

### 1.23.0 / 2021-03-16
* Added:
  * For `podman` support:
    * Bumped the required beaker-docker to between 0.8.3 and 2.0.0
    * Added a dependency on docker-api between 2.1.0 and 3.0.0
  * Make SSG failures have verbose output to make remediation easier
* Fixed:
  * Ensure that containers use the correct method for copying files

### 1.22.1 / 2021-03-01
* Fixed: enable_epel_on() now installs the correct EPEL repository
  package on OracleLinux

### 1.22.0 / 2021-01-27
* Fixed:
  * Ensure that the simp-crypto_policy module is installed when flipping to FIPS
    mode
  * Only attempt to install the simp repos once in case they are broken for some
    reason
* Added:
  * Documentation for all of the beaker environment variables
  * set_simp_repo_release() for setting the release and release_type of the
    public SIMP yum repos
  * set_yum_opts_on() method for setting bulk yum config options
  * set_yum_opt_on() method for setting singular yum config options
  * install_package_unless_present_on() method
  * Allow users to set repos to disable using an environment variable
  * A total run time summary for beaker suites

### 1.21.4 / 2021-01-21
* Fixed:
  * Reverted the use of OpenStruct due to issues with seralization
  * Hash objects have a 'dig' method as of Ruby 2.3 so pinned this gem to a
    minimum version of Ruby 2.3

### 1.21.3 / 2021-01-20
* Fixed:
  * Allow all methods that can safely take SUT arrays to do so
  * Ensure that pfact_on returns a Hash if appropriate
  * Fix container support in copy_to
* Added:
  * Explicitly support podman local and remote in copy_to

### 1.21.2 / 2021-01-15
* Fixed version mismatch.  1.21.1 was tagged with an incorrect version
  in version.rb.

### 1.21.1 / 2021-01-13
* Added:
  * update_package_from_centos_stream method
  * install_latest_package_on method
* Fixed:
  * Removed some of the extraneous calls to facter
  * Automatically pull the CentOS 8 kernel to the latest version in
    CentOS-Stream to work around issues on FIPS systems

### 1.20.1 / 2021-01-08
* Fixed:
  * Ensure that yum calls commands appropriately depending on whether or not
    packages are already installed.
  * Also change all HostKeyAlgorithms settings for SSH connections

### 1.20.0 / 2021-01-05
* Added:
  * A `enable_epel_on` function that follows the instructions on the EPEL
    website to properly enable EPEL on hosts. May be disabled using
    `BEAKER_enable_epel=no`.
  * An Ubuntu nodeset to make sure our default settings don't destroy other
    Linux systems.
  * Added has_crypto_policies method for determining if crypto policies are
    present on the SUT
  * Added munge_ssh_crypto_policies to allow vagrant to SSH back into systems
    with restrictive crypto policies (usually FIPS)
* Fixed:
  * Modify all crypto-policy backend files to support ssh-rsa keys
  * Try harder when doing yum installations

### 1.19.4 / 2021-01-05
* Fixed:
  * Only return a default empty string when `pfact_on` finds a `nil` value
    * Added an acceptance test to validate this
  * Ensure that we start with `facter -p` for `facter` < 4.0 and continue to
      `puppet facts` otherwise
  * Updated the Rakefile to skip symlinks in chmods which fixes the ability to
    build gems

### 1.19.3 / 2021-01-01
* Fixed:
  * Ensure that `pfact_on` can handle fact dot notation
* Changed:
  * Silenced some of the noisy commands that didn't provide value-add output

### 1.19.2 / 2020-12-19
* Fixed:
  * Fixed an issue with pfact_on

### 1.19.1 / 2020-12-02
* Fixed:
  * Bumped the core puppet version to 6.X
  * Fixed the file_content_on method
  * Removed EL 6 support from the tests since the core repos are defunct
  * Started removing some of the puppet 4 tests

### 1.19.0 / 2020-09-30
* Fixed:
  * rsync handling has a better check to see if rsync actually works prior to
    using it.  The old method had the potential to try and use rsync even if it
    no longer worked (FIPS flipped for example).
* Changed:
  * Migrated from PackageCloud to the SIMP download server for updates moving
    forward.

### 1.18.9 / 2020-08-04
* Change windows 2012r2 VM to work around issues where the old image had
  duplicate ports trying to be opened
* Increase test CA bits to 4096

### 1.18.8 / 2020-07-14
* Allow the beaker version to be pinned by environment variable

### 1.18.7 / 2020-07-07
* Fix host reference bug when switching to FIPS mode
* Ensure that net-ssh 6+ can access older FIPS systems

### 1.18.6 / 2020-06-24
* Fix Vagrant snapshot issues

### 1.18.5 / 2020-06-24
* Allow Vagrant to connect to EL8+ hosts in FIPS mode
* Add EL8 support to the SSG scans

### 1.18.4 / 2020-03-31
* Fix capturing error messages when inspec fails to generate results

### 1.18.3 / 2020-02-24
* Fix the Windows library loading location.
  * No longer attempt to load windows libraries by default unless the system is
    actually Windows

### 1.18.2 / 2020-02-24

* The previous location for loading the Windows libraries would not work in a
  `:before` block. This moves it into its own module space.
* Bump to the working version of beaker and beaker-puppet

### 1.18.1 / 2020-02-12
* Fix gemspec dependencies
* Fix the windows library loading location

### 1.18.0 / 2020-02-06
* Update Windows support
  * Add require beaker-windows and note installation of gem if missing
  * Add geotrust global CA certificate in fix_eratta_on
* Added convenience helper methods
  * Add puppet_environment_path_on
  * Add file_content_on which is multi-platform safe unlike the built-in
    file_contents_on
  * Add hiera_config_path_on
  * Add get_hiera_config_on
  * Add set_hiera_config_on

### 1.17.1 / 2019-11-01
* Only pull in the beaker rake tasks from the puppetlabs helpers

### 1.17.0 / 2019-10-22
* Allow users to perform exclusion filters on SSG results
* Allow users to pass Arrays of items to match for SSG results

### 1.16.2 / 2019-10-10
* Pull latest inspec package now that the upstream bug is fixed

### 1.16.1 / 2019-09-25
* Remove debugging pry that was accidentally left in

### 1.16.0 / 2019-09-23
* Added a sosreport function to gather SOS Reports from EL systems

### 1.15.2 / 2019-09-13
* Fix an issue where the inspec reports were not processed properly

### 1.15.1 / 2019-08-26
* Ensure that any user on the SUT can use the RedHat entitlements

### 1.15.0 / 2019-08-08
* Add the ability to handle registration of Red Hat hosts with the RHN.

### 1.14.6 / 2019-08-15
* Add Windows client support to the beaker helpers functions
  * Added an `is_windows?(sut)` function
  * Work around issues with calling `sut.puppet` on Windows SUTs
  * Update `copy_fixture_modules_to` to support Windows (slow copy)
  * Add Windows support to `puppet_modulepath_on`

### 1.14.5 / 2019-08-14
* Update the CentOS SSG hooks to properly work with CentOS 6

### 1.14.4 / 2019-07-26
* Bump the version of Highline to 2.0+ due to bugs in the latest 1.X series

### 1.14.3 / 2019-06-24
* Add RPM-GPG-KEY-SIMP-6 to the SIMP dependencies repo created
  by install_simp_repo.

### 1.14.2 / 2019-05-16
* Move the minimum supported puppet version to Puppet 5 since Puppet 4 has been
  removed from the download servers completely. Beaker may re-add support for
  the new location so not removing the mappings at this time.
* Fixed a bug where a hash item was incorrect and not properly passing along
  configuration items.

### 1.14.1 / 2019-04-15
* Handle license acceptance option needed for new versions of inspec.

### 1.14.0 / 2019-04-08
* Added function, install_simp_repo, to install the simp online repos.
  The repos are defined in a hash in the function. All the repos
  will be configured and enabled.   To disable one or more of them pass
  in an array of names of the repos to disable.

### 1.13.1 / 2019-02-02
* Ensure that SUTs have an FQDN set and not just a short hostname
* Work around issue where the SSG doesn't build the STIG for CentOS any longer.
* Add a work around for getting the docker SUT ID due to breaking changes in
  the beaker-docker gem

### 1.13.0 / 2018-11-09
* Make the SSG reporting consistent with the InSpec reporting
  * Thanks to Liz Nemsick for the original result processing code

### 1.12.2 / 2018-10-25
* Skip most of fix_errata_on on windows platforms

### 1.12.1 / 2018-10-24
* Fall back to SSH file copies automatically when rsync does not work due to
  test cases that affect ssh directly and that will cause new sessions to fail.

### 1.12.0 / 2018-10-22
* When using suites, allow users to loop through multiple specified nodesets as
  a colon delimited list or loop through all nodesets by passing 'ALL'.
* If 'ALL' is passed, the 'default' suite will be run first.

### 1.11.3 / 2018-10-22
* Made the inspec report less confusing overall by noting where checks are
  overridden
* Fix errors in the previous ssh key copy

### 1.11.2 / 2018-10-11
* Copy ssh keys in home directories to simp standard '/etc/ssh/local_keys/'
  to avoid error when certain simp puppet modules are applied
* Fix enable_fips_mode_on(), which no longer works on centos/7 vagrant boxes.

### 1.11.1 / 2018-10-03
* Deprecate the 'terminus' parameter in 'write_hieradata_to' and 'set_hieradata_on'
* Add 'copy_hiera_data_to' method to replace the one from beaker-hiera
* Add 'hiera_datadir' method to replace the one from beaker-hiera
* Change InSpec to use the 'reporter' option instead of 'format'
* Update the SSG to point to the new ComplianceAsCode repository

### 1.11.0 / 2018-10-01
* Add support for Beaker 4

### 1.10.14 / 2018-08-01
* Pinned `net-telnet` to `~> 0.1.1` for all releases due to dropping support
  for Ruby less than 2.3 in `0.2.X`. This should be removed once we drop
  support for Ruby 1.9 (late October 2018).

### 1.10.13 / 2018-07-24
* Update puppet to puppet-agent mapping table for puppet-agent 1.10.14

### 1.10.12 / 2018-07-09
* Forced all parallelization to `false` by default due to random issues with
  Beaker

### 1.10.11 / 2018-06-25
* Pinned `fog-openstack` to `0.1.25` for all releases due to dropping support
  for Ruby 1.9 in `0.1.26`. This should be removed once we drop support for
  Ruby 1.9 (late October 2018)
* Added removal of `.vendor` directory which was preventing successful
  deployment status in Travis CI

### 1.10.10 / 2018-06-22
* Version bump due to being released without a git tag

### 1.10.9 / 2018-06-22
* Ensure that the SSG is built from the latest tag instead of master
* Provide the option to pass a specific branch to the SSG builds
* Pin the suite base directory off of the global base directory instead of
  local to wherever the system happens to be at the time.

### 1.10.8 / 2018-05-18
* New env var BEAKER_no_fix_interfaces, set to skip the fix that brings up all
  vagrant interfaces
* Parallelized pre-test setup actions that are used across all hosts using `block_on`
* Add runtime dependency on `highline` for the `inspec` reporting

### 1.10.7 / 2018-05-11
* Updated README
* Changed acceptance tests to use `beaker:suites`
* Removed all Puppet 5+ mappings and updated the install method to figure out
  what to use based on the available gems so that everything is now consistent

### 1.10.6 / 2018-05-07
* Added Simp::BeakerHelpers.tmpname method to work around the removal of
  Dir::Tmpname in Ruby 2.5

### 1.10.5 / 2018-04-27
* Fix issue with direct copy to/from docker containers
* Add necessary package for SSG builds
* Added the downloaded inspec_deps directory to the clean list

### 1.10.4 / 2018-04-25
* Fix Inspec report failures
* Fix SSG build failures
* Allow the SSG remediation acceptance test to fail

### 1.10.3 / 2018-03-23
* Avoid warnings when using `puppet config print`

### 1.10.2 / 2018-03-04
* Reimplemented `pluginsync_on` with a Puppet manifest to completely mimic
  a native pluginsync
  - Syncs _all_ assets (e.g., augeas lenses) instead of just the facts
  - Simpler
  - Much faster, especially with many modules or SUTs

### 1.10.1 / 2018-02-13
* Updated the Puppet version mapping list for Puppet 5
* Fixed a bug in the way that the latest Puppet 5 version was being determined

### 1.10.0 / 2018-01-23
* Add support for Puppet 5
  * Note: you need to set 'puppet_collection' to 'puppet5' to test Puppet 5 and
    'aio' (or leave it out) to test Puppet less than 5
* Fix support for passing the 'ALL' suite to run all suites
* Updates per Rubocop

* Ensure that `rsync` is not used once `fips` is enabled on the SUT
  * If `fips` is enabled on the SUT, but not the running host, rsync
    connections have a high likelihood of failing

### 1.9.0 / 2018-01-01
* Ensure that all host IP addresses get added to the internally generated PKI
  keys as subjectAltNames. Kubernetes needs this and it does not hurt to have
  in place for testing.

### 1.8.10 / 2017-11-02
* Fix bug in which dracut was not run on CentOS6, when dracut-fips was
  installed for a FIPS-enabled test.
