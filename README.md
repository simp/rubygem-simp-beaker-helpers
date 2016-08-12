# simp-beaker-helpers

Methods to assist beaker acceptance tests for SIMP.

#### Table of Contents
1. [Overview](#overview)
2. [Setup](#setup)
    * [Beginning with simp-beaker-helpers](#beginning-with-simp-beaker-helpers)
3. [General Enhancements](#general-enhancements)
    * [Suites](#suites)
4. [Nodeset Enhancements](#nodeset-enhancements)
    * [YUM Repo Support](#yum_repo_support)
5. [Methods](#methods)
    * [`copy_fixture_modules_to`](#copy_fixture_modules_to)
    * [`fix_errata_on`](#fix_errata_on)
    * PKI
      * [`run_fake_pki_ca_on`](#run_fake_pki_ca_on)
      * [`copy_pki_to`](#copy_pki_to)
      * [`copy_keydist_to`](#copy_keydist_to)
    * Custom facts
      * [`pfact_on`](#pfact_on)
      * [`pluginsync_on`](#pluginsync_on)
    * Hiera
      * [`write_hieradata_to`](#write_hieradata_to)
      * [`set_hieradata_on`](#set_hieradata_on)
      * [`clear_temp_hieradata`](#clear_temp_hieradata)
6. [Environment variables](#environment-variables)
    * [`BEAKER_fips`](#beaker_fips)
    * [`BEAKER_spec_prep`](#beaker_spec_prep)
    * [`BEAKER_stringify_facts`](#beaker_stringify_facts)
    * [`BEAKER_use_fixtures_dir_for_modules`](#beaker_use_fixtures_dir_for_modules)
7. [Examples](#examples)
    * [Prep OS, Generate and copy PKI certs to each SUT](#prep-os-generate-and-copy-pki-certs-to-each-sut)
8. [License](#license)

## Overview

## Setup

### Beginning with simp-beaker-helpers

Add this to your project's `Gemfile`:

```ruby
gem 'simp-beaker-helpers'
```

Add this to your project's `spec/spec_helper_acceptance.rb`:
```ruby
require 'simp/beaker_helpers'
include Simp::BeakerHelpers
```
## General Enhancements

### Suites

The 'beaker:suites' rake task provides the ability to run isolated test sets
with a full reset of the Beaker environment.

These are entirely isolated runs of Beaker and have been designed to be used
for situations where you need to eliminate all of the cruft from your previous
runs to perform a new type of test.

#### Suite Execution

By default the only suite that will be executed is `default`.  Since each suite
is executed in a new environment, spin up can take a lot of time. Therefore,
the default is to only run the default suite.

If there is a suite where the metadata contains `default_run` set to the
Boolean `true`, then that suite will be part of the default suite execution.

You can run all suites by setting the passed suite name to `ALL` (case
sensitive).

#### Environment Variables

* BEAKER_suite_runall
  * Run all Suites

* BEAKER_suite_basedir
  * The base directory where suites will be defined
  * Default: spec/acceptance

#### Global Suite Configuration

A file `config.yml` can be placed in the `suites` directory to control certain
aspects of the suite run.

##### Supported Config:

```yaml
---
# Fail the entire suite at the first failure
'fail_fast' : <true|false> => Default: true
```

#### Individual Suite Configuration

Each suite may contain a YAML file, metadata.yml, which will be used to provide
information to the suite of tests.

##### Supported Config:

```yaml
---
'name' : '<User friendly name for the suite>'

# Run this suite by default
'default_run' : <true|false> => Default: false
```

## Nodeset Enhancements

### YUM Repo Support

Nodes in your nodesets will create YUM repository entries according to the
following Hash:

```yaml
---
yum_repos:
   <repo_name>:
     <yum_resource_parameter>: <value>
```

The `baseurl` and `gpgkey` parameters can also take an Array if you need to
point at more than one location.

This would look like the following:

```yaml
---
yum_repos:
   <repo_name>:
     baseurl:
       - http://some.random.host
       - https://some.other.random.host
     gpgkey:
       - https://my.gpg.host
       - https://my.other.gpg.host
```

## Methods

#### `copy_fixture_modules_to`

Copies the local fixture modules (under `spec/fixtures/modules`) onto a list of
SUTs.

```ruby
copy_fixture_modules_to( suts = hosts, opts = {} )
```
  - **`suts`**   = _(Array,String)_ list of SUTs to copy modules to
  - **`opts`**   = _(Hash)_ Options passed on to `copy_module_to()` for each SUT

By default, this will copy modules to the first path listed in each SUT's
`modulepath` and simulate a pluginsync so the Beaker DSL's `facter_on` will
still work.

If you need to use a non-default module path:
```ruby
# WARNING: this will use the same :target_module_dir for each SUT
copy_fixture_modules_to( hosts, {
   :target_module_dir => '/path/to/my/modules',
})
```

If you want to disable pluginsync:
```ruby
# WARNING: `fact_on` will not see custom facts
copy_fixture_modules_to( hosts, {
   :pluginsync => false
})
```

#### `fix_errata_on`

Apply any OS fixes we need on each SUT
`fix_errata_on( suts = hosts )`


#### `run_fake_pki_ca_on`

Generate a fake openssl CA + certs for each host on a given SUT and copy the
files back to a local directory.

**NOTE:** this needs to generate everything inside an SUT.  It is assumed the
SUT will have the appropriate openssl in its environment.

`run_fake_pki_ca_on( ca_sut = master, suts = hosts, local_dir = '' )`

 - **`ca_sut`**    = the SUT to generate the CA & certs on
 - **`suts`**      = list of SUTs to generate certs for
 - **`local_dir`** = local path where the CA+cert directory tree should copied back to

#### `copy_pki_to`

Copy a single SUT's PKI certs (with cacerts) onto the SUT.  This simulates the result of `pki::copy` without requiring a full master and `simp-pki` module.

The directory structure copied to the SUT is:
```
  SUT_BASE_DIR/
              pki/
                  cacerts/cacerts.pem
                  public/fdqn.pub
                  private/fdqn.pem

```

`copy_pki_to(sut, local_pki_dir, sut_base_dir = '/etc/pki/simp-testing')`


#### `copy_keydist_to`

Copy a CA keydist/ directory of CA+host certs into an SUT.

This simulates the output of FakeCA's `gencerts_nopass.sh` into `keydist/` and is useful for constructing a Puppet master SUT that will distribute PKI keys via agent runs.

`copy_keydist_to( ca_sut = master )`


#### `pfact_on`

Look up a fact on a given SUT using the `puppet fact` face.  This honors whatever facter-related settings the SUT's Puppet installation has been configured to use (i.e., `factpath`, `stringify_facts`, etc).

`pfact_on( sut, fact_name )`


#### `pluginsync_on`

Simulates a `pluginsync` (useful for deploying custom facts) on given SUTs.

`pluginsync_on( suts = hosts )`

#### `write_hieradata_to`

Writes a YAML file in the Hiera :datadir of a Beaker::Host.

**NOTE**: This is useless unless Hiera is configured to use the data file.
`Beaker::DSL::Helpers::Hiera#write_hiera_config_on` from [beaker-hiera](https://github.com/puppetlabs/beaker-hiera) may be used to configure Hiera.

`write_hieradata_to(host, hieradata, terminus = 'default')`

 - **`host`**      = _(Array,String,Symbol)_ One or more hosts to act upon
 - **`hieradata`** = _(Hash)_ The full hiera data structure to write to the system
 - **`terminus`**  = _(String)_ The file basename minus the file extension in which to write the Hiera data

#### `set_hieradata_on`

Writes a YAML file in the Hiera :datdir of a Beaker::Host, then configures the host to use that file exclusively.

**NOTE**: This is authoritative; you cannot mix this with other Hiera data sources.

`set_hieradata_on(host, hieradata, terminus = 'default')`

 - **`host`**      = _(Array,String,Symbol)_ One or more hosts to act upon
 - **`hieradata`** = _(Hash)_ The full hiera data structure to write to the system
 - **`terminus`**  = _(String)_ The file basename minus the file extension in which to write the Hiera data

####  `clear_temp_hieradata`

Clean up all temporary hiera data files; meant to be called from `after(:all)`

`clear_temp_hieradata`


## Environment variables
#### `BEAKER_fips`

_(Default: `no`)_ When set to `yes`, Beaker will enable [FIPS mode](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/sect-Security_Guide-Federal_Standards_And_Regulations-Federal_Information_Processing_Standard.html) on all SUTs before running tests.

**NOTE:** FIPS mode is only enabled on RedHat family hosts.

#### `BEAKER_spec_prep`

_(Default: `yes`)_  Ensures that each fixture module is present under
`spec/fixtures/modules`.  If any fixture modules are missing, it will run `rake
spec_prep` to populate the missing modules using `.fixtures.yml`.  Note that
this will _not_ update modules that are already present under
`spec/fixtures/modules`.


#### `BEAKER_stringify_facts`
#### `BEAKER_use_fixtures_dir_for_modules`

## Examples

### Prep OS, Generate and copy PKI certs to each SUT
This pattern serves to prepare component modules that use PKI

```ruby
# spec/spec_acceptance_helpers.rb
require 'beaker-rspec'
require 'tmpdir'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end


RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    begin
      # Install modules and dependencies from spec/fixtures/modules
      copy_fixture_modules_to( hosts )
      Dir.mktmpdir do |cert_dir|
        run_fake_pki_ca_on( default, hosts, cert_dir )
        hosts.each{ |host| copy_pki_to( host, cert_dir, '/etc/pki/simp-testing' )}
      end
    rescue StandardError, ScriptError => e
      require 'pry'; binding.pry if ENV['PRY']
    end
  end
end
```

## License
See [LICENSE](LICENSE)
