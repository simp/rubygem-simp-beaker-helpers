### 1.9.0 / 2018-01-01
* Ensure that all host IP addresses get added to the internally generated PKI
  keys as subjectAltNames. Kubernetes needs this and it does not hurt to have
  in place for testing.

### 1.8.10 / 2017-11-02
* Fix bug in which dracut was not run on CentOS6, when dracut-fips was
  installed for a FIPS-enabled test.
