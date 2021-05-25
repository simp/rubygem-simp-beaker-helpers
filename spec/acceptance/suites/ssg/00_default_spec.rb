require 'spec_helper_acceptance'

test_name 'SSG STIG Validation'

describe 'run the SSG against the STIG profile' do

  hosts.each do |host|
    context "on #{host}" do
      before(:all) do
        @ssg = Simp::BeakerHelpers::SSG.new(host)

        # If we don't do this, the variable gets reset
        @ssg_report = { :data => nil }
      end

      it 'should run the SSG' do
        profile = 'xccdf_org.ssgproject.content_profile_stig'

        @ssg.evaluate(profile)
      end

      it 'should have an SSG report' do
        # Validate that the filter works
        filter = '_rule_audit'
        host_exclusions = ['ssh_']

        @ssg_report[:data] = @ssg.process_ssg_results(filter, host_exclusions)

        expect(@ssg_report[:data]).to_not be_nil

        @ssg.write_report(@ssg_report[:data])
      end

      it 'should have a report' do
        expect(@ssg_report[:data][:report]).to_not be_nil
        puts @ssg_report[:data][:report]
      end
    end
  end
end
