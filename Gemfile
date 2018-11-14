# ------------------------------------------------------------------------------
# NOTE: SIMP Puppet rake tasks support ruby 2.1.9
# ------------------------------------------------------------------------------
gem_sources = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)

gem_sources.each { |gem_source| source gem_source }

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
gem 'rake'

group :system_tests do
  gem 'beaker'
  gem 'beaker-rspec'
  gem 'beaker-windows'
  gem 'net-ssh'
  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 5.0')
  gem 'puppetlabs_spec_helper'
  gem 'rubocop'
  gem 'rubocop-rspec'
end
