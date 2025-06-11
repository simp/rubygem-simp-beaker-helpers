# SIMP namespace
module Simp; end
# SIMP Beaker helper methods for testing
module Simp::BeakerHelpers; end

# Windows-specific helper methods
module Simp::BeakerHelpers::Windows
  begin
    require 'beaker-windows'
  rescue LoadError
    logger.error(%(You must include 'beaker-windows' in your Gemfile for windows support))
    exit 1
  end

  include BeakerWindows::Path
  include BeakerWindows::Powershell
  include BeakerWindows::Registry
  include BeakerWindows::WindowsFeature
end
