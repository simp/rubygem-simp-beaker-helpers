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
  s.add_runtime_dependency 'beaker'                      , '~> 4.0'
  s.add_runtime_dependency 'beaker-rspec'                , '~> 6.2'
  s.add_runtime_dependency 'beaker-puppet'               , '~> 1.0'
  s.add_runtime_dependency 'beaker-docker'               , '~> 0.3'
  s.add_runtime_dependency 'beaker-vagrant'              , '~> 0.5'
  s.add_runtime_dependency 'beaker-puppet_install_helper', '~> 0.9'
  s.add_runtime_dependency 'highline'                    , '~> 1.6'
  s.add_runtime_dependency 'nokogiri'                    , '~> 1.8'

  # Because net-telnet dropped support for Ruby < 2.3.0
  # TODO: Update this when we no longer support Ruby 2.1.9 (should be October 2018)
  s.add_runtime_dependency 'net-telnet', '~> 0.1.1'

  ### s.files = Dir['Rakefile', '{bin,lib,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z .`.split("\0")
  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
end
