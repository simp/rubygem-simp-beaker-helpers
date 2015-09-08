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
4. [Examples](#examples)
    * [Prep OS, Generate and copy PKI certs to each SUT](#prep-os-generate-and-copy-pki-certs-to-each-sut)
5. [License](#license)

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
  HOST_PKI_DIR/
          cacerts/cacert.pem
          public/fdqn.pub
          private/fdqn.pem

```

`copy_pki_to(sut, local_pki_dir, sut_pki_dir = '/etc/pki/simp-testing')`


#### `copy_keydist_to`

 Copy a CA keydist/ directory of CA+host certs into an SUT

This simulates the output of FakeCA's `gencerts_nopass.sh` into `keydist/` and is useful for constructing a Puppet master SUT that will distribute PKI keys via agent runs.

`def copy_keydist_to( ca_sut = master )`


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
