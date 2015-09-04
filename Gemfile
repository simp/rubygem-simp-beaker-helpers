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
