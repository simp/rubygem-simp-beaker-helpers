require 'spec_helper_acceptance'

hosts.each do |host|
  describe 'take a snapshot' do
    context "on #{host}" do
      # rubocop:disable RSpec/RepeatedExample, RSpec/RepeatedDescription
      it 'creates a file that should be saved' do
        on(host, 'echo "keep" > /root/keep')
      end
      # rubocop:enable RSpec/RepeatedExample, RSpec/RepeatedDescription

      # rubocop:disable RSpec/RepeatedExample
      it 'takes a snapshot' do
        Simp::BeakerHelpers::Snapshot.save(host, 'test')
      end
      # rubocop:enable RSpec/RepeatedExample

      # rubocop:disable RSpec/RepeatedExample, RSpec/RepeatedDescription
      it 'creates a file that should be removed' do
        on(host, 'echo "trash" > /root/trash')
      end
      # rubocop:enable RSpec/RepeatedExample, RSpec/RepeatedDescription

      # rubocop:disable RSpec/RepeatedExample, RSpec/RepeatedDescription
      it 'restores a snapshot' do
        Simp::BeakerHelpers::Snapshot.restore(host, 'test')
      end
      # rubocop:enable RSpec/RepeatedExample, RSpec/RepeatedDescription

      it 'has the keep file' do
        expect(host.file_exist?('/root/keep')).to be true
      end

      # rubocop:disable RSpec/RepeatedExample, RSpec/RepeatedDescription
      it 'does not have the trash file' do
        expect(host.file_exist?('/root/trash')).to be false
      end
      # rubocop:enable RSpec/RepeatedExample, RSpec/RepeatedDescription

      it 'creates a second file that should be saved' do
        on(host, 'echo "keep2" > /root/keep2')
      end

      # rubocop:disable RSpec/RepeatedExample
      it 'takes a snapshot with the same name' do
        Simp::BeakerHelpers::Snapshot.save(host, 'test')
      end
      # rubocop:enable RSpec/RepeatedExample

      # rubocop:disable RSpec/RepeatedExample, RSpec/RepeatedDescription
      it 'creates a file that should be removed' do
        on(host, 'echo "trash" > /root/trash')
      end
      # rubocop:enable RSpec/RepeatedExample, RSpec/RepeatedDescription

      # rubocop:disable RSpec/RepeatedExample, RSpec/RepeatedDescription
      it 'restores a snapshot' do
        Simp::BeakerHelpers::Snapshot.restore(host, 'test')
      end
      # rubocop:enable RSpec/RepeatedExample, RSpec/RepeatedDescription

      it 'has all keep files' do
        expect(host.file_exist?('/root/keep')).to be true
        expect(host.file_exist?('/root/keep2')).to be true
      end

      # rubocop:disable RSpec/RepeatedExample, RSpec/RepeatedDescription
      it 'does not have the trash file' do
        expect(host.file_exist?('/root/trash')).to be false
      end
      # rubocop:enable RSpec/RepeatedExample, RSpec/RepeatedDescription

      it 'takes a snapshot with a different name' do
        Simp::BeakerHelpers::Snapshot.save(host, 'test2')
      end

      it 'can list the snapshots' do
        expect(Simp::BeakerHelpers::Snapshot.list(host)).to eq [host.to_s, 'test', 'test2']
      end

      it 'can query for a specific snapshot' do
        expect(Simp::BeakerHelpers::Snapshot.exist?(host, 'test')).to eq true
        expect(Simp::BeakerHelpers::Snapshot.exist?(host, 'test2')).to eq true
        expect(Simp::BeakerHelpers::Snapshot.exist?(host, 'nope')).to eq false
      end

      it 'restores to the internal base' do
        Simp::BeakerHelpers::Snapshot.restore_to_base(host)
      end

      # rubocop:disable RSpec/RepeatedExample, RSpec/RepeatedDescription
      it 'creates a file that should be saved' do
        on(host, 'echo "keep" > /root/keep')
      end
      # rubocop:enable RSpec/RepeatedExample, RSpec/RepeatedDescription

      it 'creates a handoff snapshot for further tests' do
        Simp::BeakerHelpers::Snapshot.save(host, 'handoff')
      end
    end
  end
end
