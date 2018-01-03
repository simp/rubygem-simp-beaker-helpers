### 1.10.0 / 2018-01-03
* Add support for Puppet 5
  * Note: you need to set 'puppet_collection' to 'puppet5' to test Puppet 5 and
    'aio' (or leave it out) to test Puppet less than 5
* Fix support for passing the 'ALL' suite to run all suites
* Updates per Rubocop

### 1.9.0 / 2018-01-01
* Ensure that all host IP addresses get added to the internally generated PKI
  keys as subjectAltNames. Kubernetes needs this and it does not hurt to have
  in place for testing.

### 1.8.10 / 2017-11-02
* Fix bug in which dracut was not run on CentOS6, when dracut-fips was
  installed for a FIPS-enabled test.
