module Simp; end

module Simp::BeakerHelpers
  # This is the *oldest* puppet-agent version that the latest release of SIMP supports
  #
  # This is done so that we know if some new thing that we're using breaks the
  # oldest system that we support
  DEFAULT_PUPPET_AGENT_VERSION = '~> 6.0'

  SSG_REPO_URL = ENV['BEAKER_ssg_repo'] || 'https://github.com/ComplianceAsCode/content.git'

  if ['true','yes'].include?(ENV['BEAKER_online'])
    ONLINE = true
  elsif ['false','no'].include?(ENV['BEAKER_online'])
    ONLINE = false
  else
    require 'open-uri'

    begin
      ONLINE = true if open('http://google.com')
    rescue
      ONLINE = false
    end
  end
end
