require 'spec_helper_acceptance'

test_name 'SSG Functionality Validation'

describe 'run the SSG against an SCAP profile' do
  hosts.each do |host|
    context "on #{host}" do
      before(:all) do
        @ssg = Simp::BeakerHelpers::SSG.new(host)

        # If we don't do this, the variable gets reset
        @ssg_report = { data: nil }
      end

      it 'runs the SSG' do
        profiles = @ssg.get_profiles

        profile = profiles.find { |x| x.include?('_stig') } ||
                  profiles.find { |x| x.include?('_cui') } ||
                  profiles.find { |x| x.include?('_ospp') } ||
                  profiles.find { |x| x.include?('_standard') } ||
                  profiles.last

        expect(profile).not_to be_nil
        @ssg.evaluate(profile)
      end

      it 'has an SSG report' do
        # Validate that the filter works
        filter = '_rule_audit'
        host_exclusions = ['ssh_']

        @ssg_report[:data] = @ssg.process_ssg_results(filter, host_exclusions)

        expect(@ssg_report[:data]).not_to be_nil

        @ssg.write_report(@ssg_report[:data])
      end

      it 'has a report' do
        expect(@ssg_report[:data][:report]).not_to be_nil
        puts @ssg_report[:data][:report]
      end
    end
  end
end
