module Simp::BeakerHelpers

  # This is primarily designed for testing YUM installation but can be used for
  # serving up any directory on the local system.
  #
  # The environment variables should be used in your nodesets to auto-hook the
  # yum repositories if being used for that purpose.
  class WebServe

    attr_reader :dir
    attr_reader :port

    # Start a new webrick instance on the designated port
    def initialize(dir, port=11111)
      @dir = dir
      @port = port

      if @dir
        @dir = File.expand_path(@dir)

        fail("Could not find directory to serve via webrick: '#{@dir}'") unless File.directory?(@dir)

        pid = fork do
          require 'webrick'

          server = WEBrick::HTTPServer.new(:Port => @port, :DocumentRoot => @dir)

          trap 'INT' do server.shutdown end
          trap 'HUP' do server.shutdown end
          trap 'TERM' do server.shutdown end

          server.start
        end

        at_exit do
          Process.kill("INT", pid)
        end
      end
    end
  end

  # Process the following environment variables and serve a directory via webrick
  # on the designated port.
  #
  # BEAKER_SIMP_webserve=<path to serve via webrick>
  # BEAKER_SIMP_webserve_port=<port to use (defaults to 11111)>
  #
  # When included, this code will read the environment variables and spin up a
  # Webrick web server accordingly basically a 'quick and dirty' shim around
  # having to repeat the code everywhere.
  module WebServe::Run
    dir = ENV['BEAKER_SIMP_webserve']
    port = ENV['BEAKER_SIMP_webserve_port']

    if port
      Simp::BeakerHelpers::WebServe.new(dir, port)
    else
      Simp::BeakerHelpers::WebServe.new(dir)
    end
  end
end
