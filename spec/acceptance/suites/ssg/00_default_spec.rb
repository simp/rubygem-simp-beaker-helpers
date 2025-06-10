require 'spec_helper_acceptance'

test_name 'SSG Functionality Validation'

describe 'run the SSG against an SCAP profile' do
  hosts.each do |host|
    context "on #{host}" do
      let(:ssg) { Simp::BeakerHelpers::SSG.new(host) }

      let(:ssg_report_data) do
        # Validate that the filter works
        filter = '_rule_audit'
        host_exclusions = ['ssh_']

        ssg.process_ssg_results(filter, host_exclusions)
      end

      it 'runs the SSG' do
        profiles = ssg.get_profiles

        profile = profiles.find { |x| x.include?('_stig') } ||
                  profiles.find { |x| x.include?('_cui') } ||
                  profiles.find { |x| x.include?('_ospp') } ||
                  profiles.find { |x| x.include?('_standard') } ||
                  profiles.last

        expect(profile).not_to be_nil
        ssg.evaluate(profile)
      end

      it 'has an SSG report' do
        expect(ssg_report_data).not_to be_nil

        ssg.write_report(ssg_report_data)
      end

      it 'has a report' do
        expect(ssg_report_data[:report]).not_to be_nil
        puts ssg_report_data[:report]
      end
    end
  end
end
