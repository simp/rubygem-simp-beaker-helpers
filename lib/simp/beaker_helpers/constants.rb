# SIMP namespace
module Simp; end

# SIMP Beaker helper methods for testing
module Simp::BeakerHelpers
  # This is the *oldest* puppet-agent version that the latest release of SIMP supports
  #
  # This is done so that we know if some new thing that we're using breaks the
  # oldest system that we support
  DEFAULT_PUPPET_AGENT_VERSION = '~> 8.0'.freeze

  if ['true', 'yes'].include?(ENV['BEAKER_online'])
    ONLINE = true
  elsif ['false', 'no'].include?(ENV['BEAKER_online'])
    ONLINE = false
  else
    require 'open-uri'

    begin
      if URI.respond_to?(:open)
        ONLINE = true if URI.open('http://google.com')
      elsif open('http://google.com')
        ONLINE = true
      end
    rescue
      ONLINE = false
    end
  end
end
