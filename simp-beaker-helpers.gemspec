# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'simp/beaker_helpers.rb'
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
  s.add_runtime_dependency 'beaker', '~> 2'

  ### s.files = Dir['Rakefile', '{bin,lib,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z .`.split("\0")
  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
end
