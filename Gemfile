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
  gem 'pry'
  gem 'beaker'
  gem 'beaker-rspec'
  gem 'net-ssh'
  gem 'puppetlabs_spec_helper'
  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 4.0')
end
