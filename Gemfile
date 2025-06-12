# frozen_string_literal: true

gem_sources = ENV.fetch('GEM_SERVERS', 'https://rubygems.org').split(%r{[, ]+})

gem_sources.each { |gem_source| source gem_source }

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'rake'

group :system_tests do
  beaker_gem_options = ENV.fetch('BEAKER_GEM_OPTIONS', ['>= 4.28.1', '< 7.0.0'])

  if beaker_gem_options.to_s.include?(':')
    # Just pass in BEAKER_GEM_OPTIONS as a string that would represent the usual
    # hash of options.
    #
    # Something like: BEAKER_GEM_OPTIONS=':git => "https://my.repo/beaker.git", :tag => "1.2.3"'
    #
    # No, this isn't robust, but it's not really an 'every day' sort of thing
    # and safer than an `eval`
    begin
      beaker_gem_options = Hash[
        beaker_gem_options.split(',').
                           # Split passed options on k/v pairs
                           map { |x| x.gsub('"', '').strip.split(%r{:\s|\s+=>\s+}) }. # Allow for either format hash keys
                           map { |k, v| [k.delete(':').to_sym, v.strip] } # Convert all keys to symbols
      ] # Convert the whole thing to a valid Hash
    rescue StandardError => e
      raise "Invalid BEAKER_GEM_OPTIONS: '#{beaker_gem_options}' => '#{e}'"
    end
  end

  gem 'beaker', beaker_gem_options

  gem 'bcrypt_pbkdf'
  gem 'beaker-rspec'
  gem 'beaker_puppet_helpers'
  gem 'beaker-windows'
  gem 'ed25519'
  gem 'net-ssh'
  gem 'pry-byebug', '~> 3.10.0'
  gem 'puppet', ENV.fetch('PUPPET_VERSION', ['>= 7.0.0', '< 9.0.0'])
  gem 'puppetlabs_spec_helper', '>= 4.0.0', '< 8.0.0'
  gem 'rubocop', '~> 1.69.2'
  gem 'rubocop-performance', '~> 1.23.0'
  gem 'rubocop-rake', '~> 0.6.0'
  gem 'rubocop-rspec', '~> 3.3.0'
end

gem "pry", "~> 0.15.2"
