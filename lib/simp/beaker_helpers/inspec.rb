module Simp::BeakerHelpers
  # Helpers for working with Inspec
  class Inspec

    require 'json'

    attr_reader :profile
    attr_reader :profile_dir
    attr_reader :deps_root

    # Create a new Inspec helper for the specified host against the specified profile
    #
    # @param sut
    #   The SUT against which to run
    #
    # @param profile
    #   The name of the profile against which to run
    #
    def initialize(sut, profile)
      @sut = sut

      @sut.install_package('inspec')

      os = fact_on(@sut, 'operatingsystem')
      os_rel = fact_on(@sut, 'operatingsystemmajrelease')

      @profile = "#{os}-#{os_rel}-#{profile}"
      @profile_dir = '/tmp/inspec/inspec_profiles'
      @deps_root = '/tmp/inspec'

      @test_dir = @profile_dir + "/#{@profile}"

      sut.mkdir_p(@profile_dir)

      output_dir = File.absolute_path('sec_results/inspec')

      unless File.directory?(output_dir)
        FileUtils.mkdir_p(output_dir)
      end

      local_profile = File.join(fixtures_path, 'inspec_profiles', %(#{os}-#{os_rel}-#{profile}))
      local_deps = File.join(fixtures_path, 'inspec_deps')

      @result_file = File.join(output_dir, "#{@sut.hostname}-inspec-#{Time.now.to_i}")

      copy_to(@sut, local_profile, @profile_dir)

      if File.exist?(local_deps)
        copy_to(@sut, local_deps, @deps_root)
      end

      # The results of the inspec scan in Hash form
      @results = {}
    end

    # Run the inspec tests and record the results
    def run
      sut_inspec_results = '/tmp/inspec_results.json'

      inspec_cmd = "inspec exec '#{@test_dir}' --reporter json > #{sut_inspec_results}"
      result = on(@sut, inspec_cmd, :accept_all_exit_codes => true)

      tmpdir = Dir.mktmpdir
      begin
        Dir.chdir(tmpdir) do
          if @sut[:hypervisor] == 'docker'
            # Work around for breaking changes in beaker-docker
            if @sut.host_hash[:docker_container]
              container_id = @sut.host_hash[:docker_container].id
            else
              container_id = @sut.host_hash[:docker_container_id]
            end

            %x(docker cp "#{container_id}:#{sut_inspec_results}" .)
          else
            scp_from(@sut, sut_inspec_results, '.')
          end

          local_inspec_results = File.basename(sut_inspec_results)

          if File.exist?(local_inspec_results)
            begin
              # The output is occasionally broken from past experience. Need to
              # fetch the line that actually looks like JSON
              inspec_json = File.read(local_inspec_results).lines.find do |line|
                line.strip!

                line.start_with?('{') && line.end_with?('}')
              end

              @results = JSON.load(inspec_json) if inspec_json
            rescue JSON::ParserError, JSON::GeneratorError
              @results = nil
            end
          end
        end
      ensure
        FileUtils.remove_entry_secure tmpdir
      end

      unless @results
        File.open(@result_file + '.err', 'w') do |fh|
          fh.puts(result.stderr.strip)
        end

        err_msg = ["Error running inspec command #{inspec_cmd}"]
        err_msg << "Error captured in #{@result_file}" + '.err'

        fail(err_msg.join("\n"))
      end
    end

    # Output the report
    #
    # @param report
    #   The inspec results Hash
    #
    def write_report(report)
      File.open(@result_file + '.json', 'w') do |fh|
        fh.puts(JSON.pretty_generate(@results))
      end

      File.open(@result_file + '.report', 'w') do |fh|
        fh.puts(report[:report].uncolor)
      end
    end

    def process_inspec_results
      self.class.process_inspec_results(@results)
    end

    # Process the results of an InSpec run
    #
    # @return [Hash] A Hash of statistics and a formatted report
    #
    def self.process_inspec_results(results)
      require 'highline'

      HighLine.colorize_strings

      stats = {
        # Legacy metrics counters for backwards compatibility
        :failed     => 0,
        :passed     => 0,
        :skipped    => 0,
        :overridden => 0,
        # End legacy stuff
        :global   => {
          :failed     => [],
          :passed     => [],
          :skipped    => [],
          :overridden => []
        },
        :score    => 0,
        :report   => nil,
        :profiles => {}
      }

      if results.is_a?(String)
        if File.readable?(results)
          profiles = JSON.load(File.read(results))['profiles']
        else
          fail("Error: Could not read results file at #{results}")
        end
      elsif results.is_a?(Hash)
        profiles = results['profiles']
      else
        fail("Error: first argument must be a String path to a file or a Hash")
      end

      if !profiles || profiles.empty?
        fail("Error: Could not find 'profiles' in the passed results")
      end

      profiles.each do |profile|
        profile_name = profile['name']

        next unless profile_name

        stats[:profiles][profile_name] = {
          :controls => {}
        }

        profile['controls'].each do |control|
          title = control['title']

          next unless title

          stats[:profiles][profile_name][:controls][title] = {}

          formatted_title = title.scan(/.{1,72}\W|.{1,72}/).map(&:strip).join("\n           ")

          stats[:profiles][profile_name][:controls][title][:formatted_title] = formatted_title

          if control['results'] && !control['results'].empty?
            status = control['results'].first['status']

            if status == /^fail/
              status = :failed
              color = 'red'
            else
              status = :passed
              color = 'green'
            end
          else
            status = :skipped
            color = 'yellow'
          end

          stats[:global][status] << title.to_s.color

          stats[:profiles][profile_name][:controls][title][:status] = status
          stats[:profiles][profile_name][:controls][title][:source] = control['source_location']['ref']
        end
      end

      valid_checks = stats[:global][:failed] + stats[:global][:passed]
      stats[:global][:skipped].dup.each do |skipped|
        if valid_checks.include?(skipped)
          stats[:global][:overridden] << skipped
          stats[:global][:skipped].delete(skipped)
        end
      end

      status_colors = {
        :failed     => 'red',
        :passed     => 'green',
        :skipped    => 'yellow',
        :overridden => 'white'
      }

      report = []

      stats[:profiles].keys.each do |profile|
        report << "Profile: #{profile}"

        stats[:profiles][profile][:controls].each do |control|
          control_info = control.last

          report << "\n  Control: #{control_info[:formatted_title]}"

          if control_info[:status] == :skipped && stats[:global][:overridden].include?(control.first)
            control_info[:status] = :overridden
          end

          report << "    Status: #{control_info[:status].to_s.send(status_colors[control_info[:status]])}"
          report << "    File: #{control_info[:source]}" if control_info[:source]
        end

        report << "\n"
      end

      num_passed     = stats[:global][:passed].count
      num_failed     = stats[:global][:failed].count
      num_skipped    = stats[:global][:skipped].count
      num_overridden = stats[:global][:overridden].count

      # Backwards compat values
      stats[:passed]     = num_passed
      stats[:failed]     = num_failed
      stats[:skipped]    = num_skipped
      stats[:overridden] = num_overridden

      report << "Statistics:"
      report << "  * Passed: #{num_passed.to_s.green}"
      report << "  * Failed: #{num_failed.to_s.red}"
      report << "  * Skipped: #{num_skipped.to_s.yellow}"

      score = 0
      if (stats[:global][:passed].count + stats[:global][:failed].count) > 0
        score = ((stats[:global][:passed].count.to_f/(stats[:global][:passed].count + stats[:global][:failed].count)) * 100.0).round(0)
      end

      report << "\n Score: #{score}%"

      stats[:score] = score
      stats[:report] = report.join("\n")

      return stats
    end
  end
end
