# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'simp/beaker_helpers/version'
require 'date'

Gem::Specification.new do |s|
  s.name        = 'simp-beaker-helpers'
  s.date        = Date.today.to_s
  s.summary     = 'beaker helper methods for SIMP'
  s.description = <<~END_DESCRIPTION
    Beaker helper methods to help scaffold SIMP acceptance tests
  END_DESCRIPTION
  s.version     = Simp::BeakerHelpers::VERSION
  s.license     = 'Apache-2.0'
  s.authors     = ['Chris Tessmer', 'Trevor Vaughan']
  s.email       = 'simp@simp-project.org'
  s.homepage    = 'https://github.com/simp/rubygem-simp-beaker-helpers'
  s.metadata = {
    'issue_tracker' => 'https://github.com/simp/rubygem-simp-beaker-helpers/issues'
  }

  s.required_ruby_version = '>= 2.7.0'

  s.add_runtime_dependency 'beaker',                ['>= 4.28.1', '< 8.0.0']
  s.add_runtime_dependency 'beaker-docker',         ['>= 0.8.3', '< 4.0.0']
  s.add_runtime_dependency 'beaker-rspec',          ['>= 8.0', '< 10.0.0']
  s.add_runtime_dependency 'beaker-vagrant',        ['>= 0.6.4', '< 3.0.0']
  s.add_runtime_dependency 'beaker_puppet_helpers', ['>= 2.0.0', '< 4.0.0']
  s.add_runtime_dependency 'docker-api',            ['>= 2.1.0', '< 3.0.0']
  s.add_runtime_dependency 'highline',              ['>= 2.0', '< 4.0.0']
  s.add_runtime_dependency 'nokogiri',              '~> 1.8'

  ### s.files = Dir['Rakefile', '{bin,lib,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files -z .`.split("\0")
  s.files       = %x(git ls-files).split("\n")
  s.test_files  = %x(git ls-files -- {test,spec,features}/*).split("\n")
  s.executables = %x(git ls-files -- bin/*).split("\n").map { |f| File.basename(f) }
end
