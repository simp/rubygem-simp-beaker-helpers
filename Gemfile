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
  beaker_gem_options = ENV.fetch('BEAKER_GEM_OPTIONS', ['>= 4.28.1', '< 5.0.0'])

  if "#{beaker_gem_options}".include?(':')
    # Just pass in BEAKER_GEM_OPTIONS as a string that would represent the usual
    # hash of options.
    #
    # Something like: BEAKER_GEM_OPTIONS=':git => "https://my.repo/beaker.git", :tag => "1.2.3"'
    #
    # No, this isn't robust, but it's not really an 'every day' sort of thing
    # and safer than an `eval`
    begin
      gem 'beaker', Hash[
        beaker_gem_options.split(',').map do |x| # Split passed options on k/v pairs
          x.gsub('"', '').strip.split(/:\s|\s+=>\s+/) # Allow for either format hash keys
        end.map do |k,v|
          [
            k.delete(':').to_sym, # Convert all keys to symbols
            v.strip
          ]
        end
      ] # Convert the whole thing to a valid Hash
    rescue => e
      raise "Invalid BEAKER_GEM_OPTIONS: '#{beaker_gem_options}' => '#{e}'"
    end
  else
    gem 'beaker', beaker_gem_options
  end

  gem 'beaker-rspec'
  gem 'beaker-windows'
  gem 'net-ssh'
  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 6.0')
  gem 'puppetlabs_spec_helper', '~> 3.0'
  gem 'rubocop'
  gem 'rubocop-rspec'
end
