require 'spec_helper_acceptance'
require 'json'

test_name 'Inspec STIG Profile'

describe 'Inspec STIG Profile' do
  profiles_to_validate = ['disa_stig']

  hosts.each do |host|
    profiles_to_validate.each do |profile|
      context "for profile #{profile}" do
        context "on #{host}" do
          profile_path = File.join(
              fixtures_path,
              'inspec_profiles',
              "#{fact_on(host, 'os.name')}-#{fact_on(host, 'os.release.major')}-#{profile}",
            )

          if File.exist?(profile_path)
            let(:inspec) do
              Simp::BeakerHelpers::Inspec.enable_repo_on(hosts)
              Simp::BeakerHelpers::Inspec.new(host, profile)
            end

            let(:inspec_report_data) { nil }

            # rubocop:disable RSpec/RepeatedDescription
            it 'runs inspec' do
              inspec.run
            end
            # rubocop:enable RSpec/RepeatedDescription

            it 'has an inspec report' do
              inspec_report_data = inspec.process_inspec_results

              expect(inspec_report_data).not_to be_nil

              inspec.write_report(inspec_report_data)
            end

            it 'has a report' do
              expect(inspec_report_data[:report]).not_to be_nil
              puts inspec_report_data[:report]
            end
          else
            # rubocop:disable RSpec/RepeatedDescription
            it 'runs inspec' do
              skip("No matching profile available at #{profile_path}")
            end
            # rubocop:enable RSpec/RepeatedDescription
          end
        end
      end
    end
  end
end
