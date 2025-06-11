require 'spec_helper_acceptance'

hosts.each do |host|
  describe 'snapshot workflow' do
    context "on #{host}" do
      shared_examples_for 'a snapshot test' do
        let(:snapshots) { Simp::BeakerHelpers::Snapshot.list(host) }

        it 'restores from the initial snapshot' do
          if snapshots.include?(init_snapshot)
            Simp::BeakerHelpers::Snapshot.restore(host, init_snapshot)
          end
        end

        it 'adds the keep file if necessary' do
          if init_snapshot == 'missing'
            on(host, 'echo "keep" > /root/keep')
          end
        end

        it 'adds a tracking file' do
          on(host, 'echo "tracking" > /root/tracking')
        end

        it 'restores the snapshot' do
          if init_snapshot == 'missing'
            expect { Simp::BeakerHelpers::Snapshot.restore(host, init_snapshot) }.to raise_error(%r{not found})
            Simp::BeakerHelpers::Snapshot.restore_to_base(host)
          else
            Simp::BeakerHelpers::Snapshot.restore(host, init_snapshot)
          end
        end

        it 'has the keep file' do
          expect(host.file_exist?('/root/keep')).to be true
        end

        it 'does not have the tracking file' do
          expect(host.file_exist?('/root/tracking')).to be false
        end
      end

      context 'existing snapshot' do
        let(:init_snapshot) { 'handoff' }

        include_examples 'a snapshot test'
      end

      context 'missing snapshot' do
        let(:init_snapshot) { 'missing' }

        include_examples 'a snapshot test'
      end
    end
  end
end
