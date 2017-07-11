module Simp::BeakerHelpers
  # Helpers for working with the SCAP Security Guide
  class SSG

    if ENV['BEAKER_ssg_repo']
      GIT_REPO = ENV['BEAKER_ssg_repo']
    else
      GIT_REPO = 'https://github.com/OpenSCAP/scap-security-guide.git'
    end

    EL_PACKAGES = [
      'git',
      'cmake',
      'openscap-utils',
      'openscap-python',
      'python-lxml'
    ]

    OS_INFO = {
      'RedHat' => {
        '6' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'target'     => 'rhel6',
            'datastream' => 'ssg-rhel6-ds.xml'
          }
        },
        '7' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'target'     => 'rhel7',
            'datastream' => 'ssg-rhel7-ds.xml'
          }
        }
      },
      'CentOS' => {
        '6' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'target'     => 'rhel6',
            'datastream' => 'ssg-rhel6-ds.xml'
          }
        },
        '7' => {
          'required_packages' => EL_PACKAGES,
          'ssg' => {
            'target'     => 'centos7',
            'datastream' => 'ssg-centos7-ds.xml'
          }
        }
      }
    }

    # Create a new SSG helper for the specified host
    #
    # @param sut
    #   The SUT against which to run
    #
    def initialize(sut)
      @sut = sut

      @os = fact_on(@sut, 'operatingsystem')
      @os_rel = fact_on(@sut, 'operatingsystemmajrelease')

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

    def target
      OS_INFO[@os][@os_rel]['ssg']['target']
    end

    def remediate(profile)
      evaluate(profile, true)
    end

    def evaluate(profile, remediate=false)
      cmd = 'cd scap-security-guide && oscap xccdf eval'

      if remediate
        cmd += ' --remediate'
      end

      cmd += %( --profile #{profile} --results #{@result_file}.xml --report #{@result_file}.html #{OS_INFO[@os][@os_rel]['ssg']['datastream']})

      # We accept all exit codes here because there have occasionally been
      # failures in the SSG content and we're not testing that.

      on(@sut, cmd, :accept_all_exit_codes => true)

      ['xml', 'html'].each do |ext|
        path = "scap-security-guide/#{@result_file}.#{ext}"
        scp_from(@sut, path, @output_dir)

        fail("Could not retrieve #{path} from #{@sut}") unless File.exist?(File.join(@output_dir, "#{@result_file}.#{ext}"))
      end
    end

    private

    def get_ssg_datastream
      # Allow users to point at a specific SSG release 'tar.bz2' file
      ssg_release = ENV['BEAKER_ssg_release']

      # Grab the latest SSG release in fixtures if it exists
      ssg_release ||= Dir.glob('spec/fixtures/ssg_releases/*.bz2').last

      if ssg_release
        scp_to(@sut, ssg_release)

        on(@sut, %(mkdir -p scap-security-guide && tar -xj -C scap-security-guide --strip-components 1 -f #{ssg_release} && cp scap-security-guide/*ds.xml ~))
      else
        on(@sut, %(git clone #{GIT_REPO}))
        on(@sut, %(cd scap-security-guide/build; cmake ../; make -j4 #{OS_INFO[@os][@os_rel]['ssg']['target']}-content && cp *ds.xml ~))
      end
    end
  end
end
