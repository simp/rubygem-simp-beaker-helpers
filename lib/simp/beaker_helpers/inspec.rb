module Simp::BeakerHelpers

  # Helpers for working with Inspec
  class Inspec

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

      inspec_cmd = "inspec exec --format json #{@test_dir} > #{sut_inspec_results}"
      result = on(@sut, inspec_cmd, :accept_all_exit_codes => true)

      tmpdir = Dir.mktmpdir
      begin
        Dir.chdir(tmpdir) do
          if @sut[:hypervisor] == 'docker'
            %x(docker cp "#{@sut.hostname}:#{sut_inspec_results}" .)
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
        :passed  => 0,
        :failed  => 0,
        :skipped => 0,
        :report  => []
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
        stats[:report] << "Name: #{profile['name']}"

        profile['controls'].each do |control|
          title = control['title']

          # Skip auto-generated material
          next unless title

          if title.length > 72
            title = title[0..71] + '(...)'
          end

          title_chunks = control['title'].scan(/.{1,72}\W|.{1,72}/).map(&:strip)

          stats[:report] << "\n  Control: #{title_chunks.shift}"
          unless title_chunks.empty?
            title_chunks.map!{|x| x = "           #{x}"}
            stats[:report] << title_chunks.join("\n")
          end

          if control['results'] && !control['results'].empty?
            status = control['results'].first['status']
          else
            status = 'skipped'
          end

          status_str = "    Status: "
          if status == 'skipped'
            stats[:skipped] += 1

            stats[:report] << status_str + status.yellow
            stats[:report] << "    File: #{control['source_location']['ref']}"
          elsif status =~ /^fail/
            stats[:failed] += 1

            stats[:report] << status_str + status.red
            stats[:report] << "    File: #{control['source_location']['ref']}"
          else
            stats[:passed] += 1

            stats[:report] << status_str + status.green
          end
        end

        stats[:report] << "\n  Statistics:"
        stats[:report] << "    * Passed: #{stats[:passed].to_s.green}"
        stats[:report] << "    * Failed: #{stats[:failed].to_s.red}"
        stats[:report] << "    * Skipped: #{stats[:skipped].to_s.yellow}"

        score = 0
        if (stats[:passed] + stats[:failed]) > 0
          score = ((stats[:passed].to_f/(stats[:passed] + stats[:failed])) * 100.0).round(0)
        end

        stats[:report] << "    * Score:  #{score}%"
      end

      stats[:report] = stats[:report].join("\n")

      return stats
    end
  end
end
