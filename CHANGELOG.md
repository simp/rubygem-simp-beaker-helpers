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
