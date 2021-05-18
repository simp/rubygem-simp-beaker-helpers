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
              "#{fact_on(host, 'operatingsystem')}-#{fact_on(host, 'operatingsystemmajrelease')}-#{profile}"
            )

          unless File.exist?(profile_path)
            it 'should run inspec' do
              skip("No matching profile available at #{profile_path}")
            end
          else
            before(:all) do
              Simp::BeakerHelpers::Inspec.enable_repo_on(hosts)
              @inspec = Simp::BeakerHelpers::Inspec.new(host, profile)

              # If we don't do this, the variable gets reset
              @inspec_report = { :data => nil }
            end

            it 'should run inspec' do
              @inspec.run
            end

            it 'should have an inspec report' do
              @inspec_report[:data] = @inspec.process_inspec_results

              expect(@inspec_report[:data]).to_not be_nil

              @inspec.write_report(@inspec_report[:data])
            end

            it 'should have a report' do
              expect(@inspec_report[:data][:report]).to_not be_nil
              puts @inspec_report[:data][:report]
            end
          end
        end
      end
    end
  end
end
