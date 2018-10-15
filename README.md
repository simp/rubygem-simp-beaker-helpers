# simp-beaker-helpers

Methods to assist beaker acceptance tests for SIMP.

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
* [Setup](#setup)
  * [Beginning with simp-beaker-helpers](#beginning-with-simp-beaker-helpers)
* [Rake Tasks](#rake-tasks)
  * [`rake beaker:suites`](#rake-beakersuites)
  * [Suite Execution](#suite-execution)
    * [Environment Variables](#environment-variables)
    * [Global Suite Configuration](#global-suite-configuration)
      * [Supported Config:](#supported-config)
    * [Individual Suite Configuration](#individual-suite-configuration)
      * [Supported Config:](#supported-config-1)
* [Nodeset Enhancements](#nodeset-enhancements)
  * [YUM Repo Support](#yum-repo-support)
* [Methods](#methods)
    * [`copy_to`](#copy_to)
    * [`copy_fixture_modules_to`](#copy_fixture_modules_to)
    * [`fix_errata_on`](#fix_errata_on)
    * [`run_fake_pki_ca_on`](#run_fake_pki_ca_on)
    * [`copy_pki_to`](#copy_pki_to)
    * [`copy_keydist_to`](#copy_keydist_to)
    * [`pfact_on`](#pfact_on)
    * [`pluginsync_on`](#pluginsync_on)
    * [`write_hieradata_to`](#write_hieradata_to)
    * [`set_hieradata_on`](#set_hieradata_on)
    * [`clear_temp_hieradata`](#clear_temp_hieradata)
    * [`latest_puppet_agent_version_for(puppet_version)`](#latest_puppet_agent_version_forpuppet_version)
    * [`install_puppet`](#install_puppet)
* [Environment variables](#environment-variables-1)
    * [`BEAKER_fips`](#beaker_fips)
    * [`BEAKER_fips_module_version`](#beaker_fips_module_version)
    * [`BEAKER_spec_prep`](#beaker_spec_prep)
    * [`BEAKER_SIMP_parallel`](#beaker_simp_parallel)
    * [`BEAKER_stringify_facts`](#beaker_stringify_facts)
    * [`BEAKER_use_fixtures_dir_for_modules`](#beaker_use_fixtures_dir_for_modules)
    * [`BEAKER_no_fix_interfaces`](#beaker_no_fix_interfaces)
    * [PUPPET_VERSION](#puppet_version)
* [Examples](#examples)
  * [Prep OS, Generate and copy PKI certs to each SUT](#prep-os-generate-and-copy-pki-certs-to-each-sut)
  * [Specify the version of Puppet to run in the SUTs](#specify-the-version-of-puppet-to-run-in-the-suts)
* [License](#license)

<!-- vim-markdown-toc -->

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

## Rake Tasks

New `rake` tasks are available to help you use `beaker` more effectively.

These can be included in your `Rakefile` by adding the following:

```
require 'simp/rake/beaker'
Simp::Rake::Beaker.new(File.dirname(__FILE__))
```

### `rake beaker:suites`

The 'beaker:suites' rake task provides the ability to run isolated test sets
with a full reset of the Beaker environment.

These are entirely isolated runs of Beaker and have been designed to be used
for situations where you need to eliminate all of the cruft from your previous
runs to perform a new type of test.

### Suite Execution

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

#### `copy_to`

Abstracts copying files and directories in the most efficient manner possible.

* If your system is a ``docker`` container it uses ``docker cp``
* If your system is anything else:
  * Attempts to use ``rsync`` if it is present on both sides
  * Falls back to ``scp``

All copy semantics are consistent with what you would expect from ``scp_to``

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

#### `latest_puppet_agent_version_for(puppet_version)`

Finds the latest `puppet-agent` version based on the passed gem version and can
accept the usual Gem comparison syntax (e.g., '4.0', '=4.2', '~> 4.3.1', '5')

Returns the `puppet-agent` package version or `nil` if not found.

#### `install_puppet`

Performs an assessment of all set parameters and installs the correct
`puppet-agent` based on those parameters based on the following logic.

If the environment variable `BEAKER_PUPPET_AGENT_VERSION` or
`PUPPET_INSTALL_VERSION` or `PUPPET_VERSION` is set, it will use that value
to determine the `puppet-agent` version to install.

If it is unable to determine the `puppet-agent` version from any `*VERSION`
environment variables and the environment variable `BEAKER_PUPPET_COLLECTION`
is set, it will use this to determine which puppet collection to install from.
(Presently, this only works with Puppet 5.x and is set as `puppet5`.)

If it cannot determinte the `puppet-agent` version from any environment
variables, it will default the version to the value of
Simp::BeakerHelpers::DEFAULT_PUPPET_AGENT_VERSION, which is currently '1.10.4'.

## Environment variables

#### `BEAKER_fips`

_(Default: `no`)_ When set to `yes`, Beaker will enable [FIPS mode](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/sect-Security_Guide-Federal_Standards_And_Regulations-Federal_Information_Processing_Standard.html) on all SUTs before running tests.

**NOTE:** FIPS mode is only enabled on RedHat family hosts.

#### `BEAKER_fips_module_version`

_(Default: unset)_ Set to a version of the simp-fips Puppet module released
to Puppet Forge, when you want to specify the version of that module used to
implement enable FIPS. When unset, the latest version is used.

**NOTE:** This has no effect if the `simp-fips` module is already included in your fixtures.yml

#### `BEAKER_spec_prep`

_(Default: `yes`)_  Ensures that each fixture module is present under
`spec/fixtures/modules`.  If any fixture modules are missing, it will run `rake
spec_prep` to populate the missing modules using `.fixtures.yml`.  Note that
this will _not_ update modules that are already present under
`spec/fixtures/modules`.

#### `BEAKER_SIMP_parallel`

_(Default: `no`)_  Execute each SIMP host setup method such as
`Simp::BeakerHelpers::copy_fixure_modules_to` and `Simp::BeakerHelpers::fix_errata_on`
on all hosts in a node set in parallel. Uses parallelization provided by Beaker.

**NOTE:** Beaker's parallelization capability does not always work, so a word
to the wise is sufficient.

#### `BEAKER_stringify_facts`
#### `BEAKER_use_fixtures_dir_for_modules`

#### `BEAKER_no_fix_interfaces`

Set to skip code that makes sure all interfaces are up

#### PUPPET_VERSION

The `PUPPET_VERSION` environment variable will install the latest
`puppet-agent` package that provides that version of Puppet.  This honors
`Gemfile`-style expressions like `"~> 4.8.0"`

`BEAKER_PUPPET_AGENT_VERSION` and `PUPPET_INSTALL_VERSION` are synonyms of
`PUPPET_VERSION`.

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

### Specify the version of Puppet to run in the SUTs

```bash
# puppet-agent 1.8.3 will be installed in VMs
PUPPET_VERSION="~> 4.8.0" bundle exec rake beaker:suites

# puppet-agent 1.9.2 will be installed in VMs
PUPPET_INSTALL_VERSION=1.9.2 bundle exec rake beaker:suites

# The latest puppet 5 will be installed in VMs
PUPPET_VERSION="5" bundle exec rake beaker:suites

# puppet-agent 1.10.4 will be installed in VMs
bundle exec rake beaker:suites
```

## License
See [LICENSE](LICENSE)
