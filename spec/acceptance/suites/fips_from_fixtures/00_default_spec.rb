class ScrubFixtures
  require 'simp/beaker_helpers'
  include Simp::BeakerHelpers

  def initialize
    FileUtils.rm_rf(File.join(fixtures_path, 'modules'))
  end
end

require 'yaml'
require 'tempfile'

alt_fixtures = File.absolute_path('.fips_fixtures.yml')

new_fixtures = {
  'fixtures' => {
    'repositories' => {}
  }
}

new_fixtures['fixtures']['repositories']['crypto_policy'] = 'https://github.com/simp/pupmod-simp-crypto_policy'
new_fixtures['fixtures']['repositories']['fips'] = 'https://github.com/simp/pupmod-simp-fips'
new_fixtures['fixtures']['repositories']['augeasproviders_core'] = 'https://github.com/simp/augeasproviders_core'
new_fixtures['fixtures']['repositories']['augeasproviders_grub'] = 'https://github.com/simp/augeasproviders_grub'
new_fixtures['fixtures']['repositories']['simplib'] = 'https://github.com/simp/pupmod-simp-simplib'
new_fixtures['fixtures']['repositories']['stdlib'] = 'https://github.com/simp/puppetlabs-stdlib'

File.open(alt_fixtures, 'w'){ |fh| fh.puts(new_fixtures.to_yaml) }

ScrubFixtures.new

ENV['BEAKER_fips'] = 'yes'
ENV['FIXTURES_YML'] = alt_fixtures

beaker_gem_options = ENV['BEAKER_GEM_OPTIONS']

Bundler.with_clean_env{
  ENV['BEAKER_GEM_OPTIONS'] = beaker_gem_options
  ENV['FIXTURES_YML'] = alt_fixtures

  %x{bundle exec rake spec_prep}
}

require 'spec_helper_acceptance'

describe 'FIPS pre-installed' do
  after(:all) do
    if alt_fixtures && File.exist?(alt_fixtures)
      FileUtils.rm(alt_fixtures)

      ScrubFixtures.new
    end
  end

  hosts.each do |host|
    context "on #{host}" do
      it 'does not create an alternate apply directory' do
        if host[:hypervisor] == 'docker'
          skip('Not supported on docker')
        else
          on(host, 'test ! -d /root/.beaker_fips/modules')
        end
      end

      it 'has fips enabled' do
        if host[:hypervisor] == 'docker'
          skip('Not supported on docker')
        else
          expect(fips_enabled(host)).to be true
        end
      end
    end
  end
end
