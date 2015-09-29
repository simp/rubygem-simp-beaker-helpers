# simp-beaker-helpers

Methods to assist beaker acceptance tests for SIMP.

#### Table of Contents
1. [Overview](#overview)
2. [Setup](#setup)
    * [Beginning with simp-beaker-helpers](#beginning-with-simp-beaker-helpers)
3. [Methods](#methods)
    * [`copy_fixture_modules_to`](#copy_fixture_modules_to)
    * [`fix_errata_on`](#fix_errata_on)
    * [`run_fake_pki_ca_on`](#run_fake_pki_ca_on)
    * [`copy_pki_to`](#copy_pki_to)
    * [`copy_keydist_to`](#copy_keydist_to)
    * [`set_hieradata_on`](#set_hieradata_on)
    * [`clear_temp_hieradata`](#clear_temp_hieradata)
4. [Environment variables](#environment-variables)
    * [`BEAKER_fips`](#beaker_fips)
    * [`BEAKER_spec_prep`](#beaker_spec_prep)
    * [`BEAKER_stringify_facts`](#beaker_stringify_facts)
    * [`BEAKER_use_fixtures_dir_for_modules`](#beaker_use_fixtures_dir_for_modules)
5. [Examples](#examples)
    * [Prep OS, Generate and copy PKI certs to each SUT](#prep-os-generate-and-copy-pki-certs-to-each-sut)
6. [License](#license)

## Overview

## Setup

### Beginning with simp-beaker-helpers

Add this to your project's `Gemfile`:

```ruby
gem 'simp-beaker-helpers'
```

Add this to your project's `spec/spec_helper_acceptance.rb`:
```ruby
require 'simp-beaker-helpers'
include SIMP::BeakerHelpers
```



## Methods

#### `copy_fixture_modules_to`

Copies the local fixture modules (under `spec/fixtures/modules`) onto a list of SUTs
`copy_fixture_modules_to( suts = hosts )`


#### `fix_errata_on`

Apply any OS fixes we need on each SUT
`fix_errata_on( suts = hosts )`


#### `run_fake_pki_ca_on`

Generate a fake openssl CA + certs for each host on a given SUT and copy the
files back to a local directory.

**NOTE:** this needs to generate everything inside an SUT.  It is assumed the
SUT will have the appropriate openssl in its environment.

`run_fake_pki_ca_on( ca_sut = master, suts = hosts, local_dir = '' )`

 -  **ca_sut**    = the SUT to generate the CA & certs on
 -  **suts**      = list of SUTs to generate certs for
 -  **local_dir** = local path where the CA+cert directory tree should copied back to

#### `copy_pki_to`

Copy a single SUT's PKI certs (with cacerts) onto an SUT.  This simulates the result of `pki::copy` without requiring a full master and `simp-pki` module.

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

Copy a CA keydist/ directory of CA+host certs into an SUT

This simulates the output of FakeCA's `gencerts_nopass.sh` into `keydist/` and is useful for constructing a Puppet master SUT that will distribute PKI keys via agent runs.

`def copy_keydist_to( ca_sut = master )`


#### `set_hieradata_on`

Set the hiera data file on the provided host to the passed data structure

**NOTE**: This is authoritative; you cannot mix this with other hieradata copies

`set_hieradata_on(host, hieradata, data_file='default')`

 -  **host**      = _(Array,String,Symbol)_ One or more hosts to act upon
 -  **hieradata** = _(Hash)_ The full hiera data structure to write to the system
 -  **data_file** = _(String)_ The filename (not path) of the hiera data

####  `clear_temp_hieradata`

Clean up all temporary hiera data files; meant to be called from `after(:all)`

`clear_temp_hieradata`


## Environment variables
#### `BEAKER_fips`

SIMP acceptance tests enable [FIPS mode](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/sect-Security_Guide-Federal_Standards_And_Regulations-Federal_Information_Processing_Standard.html) on all SUTs by default.  Acceptance tests can be run without FIPS mode when `BEAKER_fips` is set to `no`

**NOTE:** FIPS mode is only enabled on RedHat family hosts

#### `BEAKER_spec_prep`
#


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
