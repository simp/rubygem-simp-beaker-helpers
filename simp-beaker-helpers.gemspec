# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'simp/beaker_helpers/version'
require 'date'

Gem::Specification.new do |s|
  s.name        = 'simp-beaker-helpers'
  s.date        = Date.today.to_s
  s.summary     = 'beaker helper methods for SIMP'
  s.description = <<-EOF
    Beaker helper methods to help scaffold SIMP acceptance tests
  EOF
  s.version     = Simp::BeakerHelpers::VERSION
  s.license     = 'Apache-2.0'
  s.authors     = ['Chris Tessmer','Trevor Vaughan']
  s.email       = 'simp@simp-project.org'
  s.homepage    = 'https://github.com/simp/rubygem-simp-beaker-helpers'
  s.metadata = {
                 'issue_tracker' => 'https://simp-project.atlassian.net'
               }
  s.add_runtime_dependency 'beaker', '~> 3.14'
  s.add_runtime_dependency 'beaker-puppet', '~> 0.8.0'
  s.add_runtime_dependency 'beaker-puppet_install_helper', '~> 0.6'
  s.add_runtime_dependency 'highline', '~> 1.6'

  # Because fog-opensack dropped support for Ruby < 2.2.0
  if RUBY_VERSION <= '2.2.0'
    s.add_runtime_dependency 'fog-openstack', '0.1.25'
  end

  ### s.files = Dir['Rakefile', '{bin,lib,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z .`.split("\0")
  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
end
