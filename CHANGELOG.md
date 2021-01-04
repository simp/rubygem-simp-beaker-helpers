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
