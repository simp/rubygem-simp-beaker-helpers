require 'rake'
require 'rake/clean'
require 'rake/tasklib'
require 'fileutils'
require 'puppetlabs_spec_helper/rake_tasks'

module Simp; end
module Simp::Rake
  class Beaker < ::Rake::TaskLib
    def initialize(base_dir)

      @base_dir   = base_dir
      @clean_list = []

      ::CLEAN.include( %{#{@base_dir}/log} )
      ::CLEAN.include( %{#{@base_dir}/junit} )

      yield self if block_given?

      ::CLEAN.include( @clean_list )

      namespace :beaker do
        desc <<-EOM
        Run a Beaker test against a specific Nodeset
          * :nodeset - The nodeset against which you wish to run
        EOM
        task :run, [:nodeset] do |t,args|
          fail "You must pass :nodeset to #{t}" unless args[:nodeset]
          nodeset = args[:nodeset].strip

          old_stdout = $stdout
          nodesets = StringIO.new
          $stdout = nodesets

          Rake::Task['beaker_nodes'].invoke

          $stdout = old_stdout

          nodesets = nodesets.string.split("\n")

          fail "Nodeset '#{nodeset}' not found. Valid Nodesets:\n#{nodesets.map{|x| x = %(  * #{x})}.join(%(\n))}" unless nodesets.include?(nodeset)

          ENV['BEAKER_set'] = nodeset

          Rake::Task['beaker'].invoke
        end
      end
    end
  end
end
