# Variables:
#
# SIMP_GEM_SERVERS | a space/comma delimited list of rubygem servers
# PUPPET_VERSION   | specifies the version of the puppet gem to load
puppetversion = ENV.key?('PUPPET_VERSION') ? "#{ENV['PUPPET_VERSION']}" : ['~>3']
gem_sources   = ENV.key?('SIMP_GEM_SERVERS') ? ENV['SIMP_GEM_SERVERS'].split(/[, ]+/) : ['https://rubygems.org']
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
  gem 'vagrant-wrapper'
  # NOTE: Workaround because net-ssh 2.10 is busting beaker
  # lib/ruby/1.9.1/socket.rb:251:in `tcp': wrong number of arguments (5 for 4) (ArgumentError)
  gem 'net-ssh', '~> 2.9.0'
  gem 'puppetlabs_spec_helper'
  gem 'puppet', puppetversion

end
