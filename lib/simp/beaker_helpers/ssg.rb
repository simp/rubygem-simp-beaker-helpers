module Simp::BeakerHelpers
  # Helpers for working with the SCAP Security Guide
  class SSG

    if ENV['BEAKER_ssg_repo']
      GIT_REPO = ENV['BEAKER_ssg_repo']
    else
      GIT_REPO = 'https://github.com/OpenSCAP/scap-security-guide.git'
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

      cmd += %( --profile #{profile} --results #{@result_file}.xml --report #{@result_file}.html #{OS_INFO[@os][@os_rel]['ssg']['datastream']})

      # We accept all exit codes here because there have occasionally been
      # failures in the SSG content and we're not testing that.

      on(@sut, cmd, :accept_all_exit_codes => true)

      ['xml', 'html'].each do |ext|
        path = "#{@scap_working_dir}/#{@result_file}.#{ext}"
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
        copy_to(@sut, ssg_release, @scap_working_dir)

        on(@sut, %(mkdir -p scap-security-guide && tar -xj -C scap-security-guide --strip-components 1 -f #{ssg_release} && cp scap-security-guide/*ds.xml #{@scap_working_dir}))
      else
        on(@sut, %(git clone #{GIT_REPO}))
        if GIT_BRANCH
          on(@sut, %(cd scap-security-guide; git checkout #{GIT_BRANCH}))
        else
          on(@sut, %(cd scap-security-guide; git checkout $(git describe --abbrev=0 --tags)))
        end
        on(@sut, %(cd scap-security-guide/build; cmake ../; make -j4 #{OS_INFO[@os][@os_rel]['ssg']['build_target']}-content && cp *ds.xml #{@scap_working_dir}))
      end
    end
  end
end
