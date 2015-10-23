# Allow a comma or space-delimited list of gem servers
if simp_gem_server =  ENV.fetch( 'SIMP_GEM_SERVERS', 'https://rubygems.org' )
  simp_gem_server.split( / |,/ ).each{ |gem_server|
    source gem_server
  }
end

# read dependencies in from the gemspec
gemspec

# mandatory gems
gem 'bundler'
gem 'rake'
gem 'puppetlabs_spec_helper'
gem 'puppet'


group :system_tests do
  gem 'pry'
  gem 'beaker'
  gem 'beaker-rspec'
  # NOTE: Workaround because net-ssh 2.10 is busting beaker
  # lib/ruby/1.9.1/socket.rb:251:in `tcp': wrong number of arguments (5 for 4) (ArgumentError)
  gem 'net-ssh', '~> 2.9.0'
end
