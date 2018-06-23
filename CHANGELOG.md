
### 1.10.9 /2018-06-22
* Ensure that the SSG is built from the latest tag instead of master
* Provide the option to pass a specific branch to the SSG builds
* Pin the suite base directory off of the global base directory instead of
  local to wherever the system happenes to be at the time.

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
