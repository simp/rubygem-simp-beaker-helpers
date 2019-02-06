module Simp::BeakerHelpers
  # Helpers for working with the SCAP Security Guide
  class SSG

    if ENV['BEAKER_ssg_repo']
      GIT_REPO = ENV['BEAKER_ssg_repo']
    else
      GIT_REPO = 'https://github.com/ComplianceAsCode/content.git'
    end

    # If this is not set, the closest tag to the default branch will be used
    GIT_BRANCH = nil

    if ENV['BEAKER_ssg_branch']
      GIT_BRANCH = ENV['BEAKER_ssg_branch']
    end

    EL_PACKAGES = [
      'PyYAML',
      'cmake',
      'git',
      'openscap-python',
      'openscap-utils',
      'python-lxml',
      'python-jinja2'
    ]

    OS_INFO = {
      'RedHat' => {
        '6' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'profile_target' => 'rhel6',
            'build_target'   => 'rhel6',
            'datastream'     => 'ssg-rhel6-ds.xml'
          }
        },
        '7' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'profile_target' => 'rhel7',
            'build_target'   => 'rhel7',
            'datastream'     => 'ssg-rhel7-ds.xml'
          }
        }
      },
      'CentOS' => {
        '6' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'profile_target' => 'rhel6',
            'build_target'   => 'rhel6',
            'datastream'     => 'ssg-rhel6-ds.xml'
          }
        },
        '7' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'profile_target' => 'rhel7',
            'build_target'   => 'centos7',
            'datastream'     => 'ssg-centos7-ds.xml'
          }
        }
      },
      'OracleLinux' => {
        '7' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'profile_target' => 'ol7',
            'build_target'   => 'ol7',
            'datastream'     => 'ssg-ol7-ds.xml'
          }
        }
      }
    }

    attr_accessor :scap_working_dir

    # Create a new SSG helper for the specified host
    #
    # @param sut
    #   The SUT against which to run
    #
    def initialize(sut)
      @sut = sut

      @os = fact_on(@sut, 'operatingsystem')
      @os_rel = fact_on(@sut, 'operatingsystemmajrelease')

      sut.mkdir_p('scap_working_dir')

      @scap_working_dir = on(sut, 'cd scap_working_dir && pwd').stdout.strip

      unless OS_INFO[@os]
        fail("Error: The '#{@os}' Operating System is not supported")
      end

      OS_INFO[@os][@os_rel]['required_packages'].each do |pkg|
        @sut.install_package(pkg)
      end

      @output_dir = File.absolute_path('sec_results/ssg')

      unless File.directory?(@output_dir)
        FileUtils.mkdir_p(@output_dir)
      end

      @result_file = "#{@sut.hostname}-ssg-#{Time.now.to_i}"


      get_ssg_datastream
    end

    def profile_target
      OS_INFO[@os][@os_rel]['ssg']['profile_target']
    end

    def remediate(profile)
      evaluate(profile, true)
    end

    def evaluate(profile, remediate=false)
      cmd = "cd #{@scap_working_dir}; oscap xccdf eval"

      if remediate
        cmd += ' --remediate'
      end

      cmd += %( --fetch-remote-resources --profile #{profile} --results #{@result_file}.xml --report #{@result_file}.html #{OS_INFO[@os][@os_rel]['ssg']['datastream']})

      # We accept all exit codes here because there have occasionally been
      # failures in the SSG content and we're not testing that.

      on(@sut, cmd, :accept_all_exit_codes => true)

      ['xml', 'html'].each do |ext|
        path = "#{@scap_working_dir}/#{@result_file}.#{ext}"
        scp_from(@sut, path, @output_dir)

        fail("Could not retrieve #{path} from #{@sut}") unless File.exist?(File.join(@output_dir, "#{@result_file}.#{ext}"))
      end
    end

    # Output the report
    #
    # @param report
    #   The results Hash
    #
    def write_report(report)
      File.open(File.join(@output_dir, @result_file) + '.report', 'w') do |fh|
        fh.puts(report[:report].uncolor)
      end
    end

    # Retrieve a subset of test results based on a match to
    # filter
    #
    # FIXME:
    # - This is a hack! Should be searching for rules based on a set
    #   set of STIG ids, but don't see those ids in the oscap results xml.
    #   Further mapping is required...
    # - Create the same report structure as inspec
    def process_ssg_results(filter=nil)
      self.class.process_ssg_results(File.join(@output_dir, @result_file) + '.xml', filter)
    end

    # Process the results of an SSG run
    #
    # @return [Hash] A Hash of statistics and a formatted report
    #
    def self.process_ssg_results(result_file, filter=nil)
      require 'highline'
      require 'nokogiri'

      HighLine.colorize_strings

      fail("Could not find results XML file '#{result_file}'") unless File.exist?(result_file)

      puts "Processing #{result_file}"
      doc = Nokogiri::XML(File.open(result_file))

      # because I'm lazy
      doc.remove_namespaces!

      if filter
        # XPATH to get the pertinent test results:
        #   Any node named 'rule-result' for which the attribute 'idref'
        #   contains filter
        result_nodes = doc.xpath("//rule-result[contains(@idref,'#{filter}')]")
      else
        result_nodes = doc.xpath('//rule-result')
      end

      stats = {
        :failed  => [],
        :passed  => [],
        :skipped => [],
        :filter  => filter.nil? ? 'No Filter' : filter,
        :report  => nil,
        :score   => 0
      }

      result_nodes.each do |rule_result|
        # Results are recorded in a child node named 'result'.
        # Within the 'result' node, the actual result string is
        # the content of that node's (only) child node.

        result = rule_result.element_children.at('result')
        result_id = rule_result.attributes['idref'].value.to_s
        result_value = [
          'Title: ' + doc.xpath("//Rule[@id='#{result_id}']/title/text()").first.to_s,
          '  ID: ' + result_id
        ].join("\n")

        if result.child.content == 'fail'
          stats[:failed] << result_value.red
        elsif result.child.content == 'pass'
          stats[:passed] << result_value.green
        else
          stats[:skipped] << result_value.yellow
        end
      end

      report = []

      report << '== Skipped =='
      report << stats[:skipped].join("\n")

      report << '== Passed =='
      report << stats[:passed].join("\n")

      report << '== Failed =='
      report << stats[:failed].join("\n")


      report << 'OSCAP Statistics:'

      if filter
        report << "  * Used Filter: 'idref' ~= '#{stats[:filter]}'"
      end

      report << "  * Passed: #{stats[:passed].count.to_s.green}"
      report << "  * Failed: #{stats[:failed].count.to_s.red}"
      report << "  * Skipped: #{stats[:skipped].count.to_s.yellow}"

      score = 0

      if (stats[:passed].count + stats[:failed].count) > 0
        score = ((stats[:passed].count.to_f/(stats[:passed].count + stats[:failed].count)) * 100.0).round(0)
      end

      report << "\n Score: #{score}%"

      stats[:score]  = score
      stats[:report] = report.join("\n")

      return stats
    end

    private

    def get_ssg_datastream
      # Allow users to point at a specific SSG release 'tar.bz2' file
      ssg_release = ENV['BEAKER_ssg_release']

      # Grab the latest SSG release in fixtures if it exists
      ssg_release ||= Dir.glob('spec/fixtures/ssg_releases/*.bz2').last

      if ssg_release
        copy_to(@sut, ssg_release, @scap_working_dir)

        on(@sut, %(mkdir -p scap-content && tar -xj -C scap-content --strip-components 1 -f #{ssg_release} && cp scap-content/*ds.xml #{@scap_working_dir}))
      else
        on(@sut, %(git clone #{GIT_REPO} scap-content))
        if GIT_BRANCH
          on(@sut, %(cd scap-content; git checkout #{GIT_BRANCH}))
        else
          on(@sut, %(cd scap-content; git checkout $(git describe --abbrev=0 --tags)))
        end

        # Work around the issue where the profiles now strip out derivative
        # content that isn't explicitlly approved for that OS. This means that
        # we are unable to test CentOS builds against the STIG, etc...
        #
        # This isn't 100% correct but it's "good enough" for an automated CI
        # environment to tell us if something is critically out of alignment.
        on(@sut, %(cd scap-content/build-scripts; sed -i 's/ssg.build_derivatives.profile_handling/#ssg.build_derivatives.profile_handling/g' enable_derivatives.py))

        on(@sut, %(cd scap-content/build; cmake ../; make -j4 #{OS_INFO[@os][@os_rel]['ssg']['build_target']}-content && cp *ds.xml #{@scap_working_dir}))
      end
    end
  end
end
