require 'rake'
require 'rake/clean'
require 'rake/tasklib'
require 'fileutils'
require 'beaker/tasks/rake_task'
require 'beaker-rspec/rake_task'
require 'puppetlabs_spec_helper/tasks/fixtures'

# SIMP namespace
module Simp; end

# Rake tasks for SIMP Beaker testing
class Simp::Rake::Beaker < ::Rake::TaskLib
  def initialize(base_dir) # rubocop:disable Lint/MissingSuper
    @base_dir   = base_dir
    @clean_list = []

    ::CLEAN.include(%(#{@base_dir}/log))
    ::CLEAN.include(%(#{@base_dir}/junit))
    ::CLEAN.include(%(#{@base_dir}/sec_results))
    ::CLEAN.include(%(#{@base_dir}/spec/fixtures/inspec_deps))

    yield self if block_given?

    ::CLEAN.include(@clean_list)

    namespace :beaker do
      desc <<-EOM
          Run a Beaker test against a specific Nodeset
            * :nodeset - The nodeset against which you wish to run
        EOM
      task :run, [:nodeset] do |t, args|
        raise "You must pass :nodeset to #{t}" unless args[:nodeset]
        nodeset = args[:nodeset].strip

        old_stdout = $stdout
        nodesets = StringIO.new
        $stdout = nodesets

        Rake::Task['beaker_nodes'].invoke

        $stdout = old_stdout

        nodesets = nodesets.string.split("\n")

        raise "Nodeset '#{nodeset}' not found. Valid Nodesets:\n#{nodesets.map { |x| %(  * #{x}) }.join(%(\n))}" unless nodesets.include?(nodeset)

        ENV['BEAKER_set'] = nodeset

        Rake::Task['beaker'].invoke
      end

      desc <<-EOM
          Run Beaker test suites.
            * :suite - A specific suite to run
              * If you set this to `ALL`, all suites will be run

            * :nodeset - A specific nodeset to run on within a specific suite
              * If you set this to `ALL`, all nodesets will be looped through, starting with 'default'
              * You may also set this to a colon delimited list of short
                nodeset names that will be run in that order

            ## Suite Execution

              By default the only suite that will be executed is `default`.
              Since each suite is executed in a new environment, spin up can
              take a lot of time. Therefore, the default is to only run the
              default suite.

              If there is a suite where the metadata contains `default_run` set
              to the Boolean `true`, then that suite will be part of the
              default suite execution.

              You can run all suites by setting the passed suite name to `ALL`
              (case sensitive).

            ## Environment Variables

              * BEAKER_suite_runall
                * Run all Suites

              * BEAKER_suite_basedir
                * The base directory where suites will be defined
                * Default: spec/acceptance

            ## Global Suite Configuration
              A file `config.yml` can be placed in the `suites` directory to
              control certain aspects of the suite run.

            ### Supported Config:

              ```yaml
              ---
              # Fail the entire suite at the first failure
              'fail_fast' : <true|false> => Default: true
              ```
            ## Individual Suite Configuration

              Each suite may contain a YAML file, metadata.yml, which will be
              used to provide information to the suite of tests.

            ### Supported Config:

              ```yaml
              ---
              'name' :        '<User friendly name for the suite>'

              # Run this suite by default
              'default_run' : <true|false> => Default: false
              ```
        EOM
      task :suites, [:suite, :nodeset] => ['spec_prep'] do |_t, args|
        suite = args[:suite]
        nodeset = args[:nodeset]

        # Record Tasks That Fail
        # Need to figure out how to capture the errors
        failures = {}

        suite_basedir = File.join(@base_dir, 'spec/acceptance/suites')

        if ENV['BEAKER_suite_basedir']
          suite_basedir = ENV['BEAKER_suite_basedir']
        end

        raise("Error: Suites Directory at '#{suite_basedir}'!") unless File.directory?(suite_basedir)

        if suite && (suite != 'ALL')
          unless File.directory?(File.join(suite_basedir, suite))
            STDERR.puts("Error: Could not find suite '#{suite}'")
            STDERR.puts('Available Suites:')
            STDERR.puts('  * ' + Dir.glob(
              File.join(suite_basedir, '*'),
            ).sort.map { |x|
              File.basename(x)
            }.join("\n  * "))
            exit(1)
          end
        end

        suite_config = {
          'fail_fast' => true
        }
        suite_config_metadata_path = File.join(suite_basedir, 'config.yml')
        if File.file?(suite_config_metadata_path)
          suite_config.merge!(YAML.load_file(suite_config_metadata_path))
        end

        suites = {}

        if suite && (suite != 'ALL')
          suites[suite] = {}
          # If a suite was set, make sure it runs.
          suites[suite]['default_run'] = true
        else
          Dir.glob(File.join(suite_basedir, '*')) do |file|
            if File.directory?(file)
              suites[File.basename(file)] = {}

              if suite == 'ALL'
                suites[File.basename(file)]['default_run'] = true
              end
            end
          end
        end

        suites.each_key do |ste|
          suites[ste]['name']  = ste
          suites[ste]['path']  = File.join(suite_basedir, ste)

          metadata_path = File.join(suites[ste]['path'], 'metadata.yml')
          if File.file?(metadata_path)
            suites[ste]['metadata'] = YAML.load_file(metadata_path)
          end

          unless File.directory?(File.join(suites[ste]['path'], 'nodesets'))
            Dir.chdir(suites[ste]['path']) do
              if File.directory?('../../nodesets')
                FileUtils.ln_s('../../nodesets', 'nodesets')
              end
            end
          end

          suites[ste].merge!(suites[ste]['metadata']) if suites[ste]['metadata']

          # Ensure that the 'default' suite runs unless explicitly disabled.
          next unless suites['default']
          if suites['default']['default_run'].nil? || (suites['default']['default_run'] == true)
            suites['default']['default_run'] = true
          end
        end

        raise("Error: No Suites Found in '#{suite_basedir}'!") if suites.empty?

        # Need to ensure that 'default' is first
        ordered_suites = suites.keys.sort
        default_suite = ordered_suites.delete('default')
        ordered_suites.unshift(default_suite) if default_suite

        suite_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ordered_suites.each do |ste|
          next unless suites[ste]['default_run'] == true

          name = suites[ste]['name']

          $stdout.puts("\n\n=== Suite '#{name}' Starting ===\n\n")

          nodesets = []
          nodeset_path = File.join(suites[ste]['path'], 'nodesets')

          if nodeset
            if nodeset == 'ALL'
              nodesets = Dir.glob(File.join(nodeset_path, '*.yml'))

              # Make sure we run the default set first
              default_set = nodesets.delete(File.join(nodeset_path, 'default.yml'))
              nodesets.unshift(default_set) if default_set
            else
              nodeset.split(':').each do |tgt_nodeset|
                nodesets << File.join(nodeset_path, "#{tgt_nodeset.strip}.yml")
              end
            end
          else
            nodesets << File.join(nodeset_path, 'default.yml')
          end

          refined_nodesets = []

          nodesets.each do |nodeset_yml|
            parsed_nodeset = ::Beaker::Options::HostsFileParser.parse_hosts_file(nodeset_yml)

            # Default to multi-node testing for backwards compatibility
            multi_node = ((parsed_nodeset[:multi_node] == false) ? false : true)

            if multi_node
              refined_nodesets.push(nodeset_yml)
            else
              parsed_nodeset_hosts = parsed_nodeset.delete(:HOSTS)

              parsed_nodeset_hosts.each do |k, v|
                v[:roles] ||= []
                v[:roles] |= ['default']

                tmp_nodeset = {
                  HOSTS: { k => v },
                  CONFIG: parsed_nodeset
                }

                tmp_nodeset_file = Tempfile.new("nodeset_#{k}-")
                tmp_nodeset_file.write(tmp_nodeset.to_yaml)
                tmp_nodeset_file.close

                refined_nodesets.push(tmp_nodeset_file.path)

                at_exit do
                  if tmp_nodeset_file && File.exist?(tmp_nodeset_file.path)
                    tmp_nodeset_file.close
                    tmp_nodeset_file.unlink
                  end
                end
              end
            end
          end

          refined_nodesets.sort.each do |nodeset_yml|
            unless File.file?(nodeset_yml)
              # Get here if user has specified a non-existent nodeset or the
              # implied `default` nodeset does not exist.
              raise("*** Suite #{name} Nodeset '#{File.basename(nodeset_yml, '.yml')}' Not Found ***") if suite_config['fail_fast']

              $stdout.puts("=== Suite #{name} Nodeset '#{File.basename(nodeset_yml, '.yml')}' Not Found, Skipping ===")
              next

            end

            ENV['BEAKER_setfile'] = nodeset_yml

            Rake::Task[:beaker].clear
            RSpec::Core::RakeTask.new(:beaker) do |tsk|
              tsk.rspec_opts = ['--color']
              tsk.pattern = File.join(suites[ste]['path'])
            end

            current_suite_task = Rake::Task[:beaker]

            if suite_config['fail_fast'] == true
              current_suite_task.execute
            else
              begin
                current_suite_task.execute
              rescue SystemExit
                failures[suites[ste]['name']] = {
                  'path'    => suites[ste]['path'],
                  'nodeset' => File.basename(nodeset_yml, '.yml')
                }
              end
            end

            $stdout.puts("\n\n=== Suite '#{name}' Complete ===\n\n")
          end
        end
        suite_end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        suite_run_time = ((suite_end_time - suite_start_time) / 60).round(2)

        $stdout.puts("== Total Runtime: #{suite_run_time} minutes ==\n\n")

        unless failures.keys.empty?
          $stdout.puts('The following tests had failures:')
          failures.keys.sort.each do |ste|
            $stdout.puts("  * #{ste} => #{failures[ste]['path']} on #{failures[ste]['nodeset']}")
          end
        end
      end
    end
  end
end
