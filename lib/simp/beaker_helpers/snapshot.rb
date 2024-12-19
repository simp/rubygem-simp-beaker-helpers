# Helpers for managing Vagrant snapshots
class Simp::BeakerHelpers::Snapshot
  # The name of the base snapshot that is created if no snapshots currently exist
  BASE_NAME = '_simp_beaker_base'.freeze

  # Save a snapshot
  #
  # @param host [Beaker::Host]
  #   The SUT to work on
  #
  # @param snapshot_name [String]
  #   The string to add to the snapshot
  #
  def self.save(host, snapshot_name)
    return unless enabled?
    vdir = vagrant_dir(host)

    return unless vdir
    Dir.chdir(vdir) do
      save(host, BASE_NAME) unless exist?(host, BASE_NAME)

      snap = "#{host.name}_#{snapshot_name}"

      output = `vagrant snapshot save --force #{host.name} "#{snap}"`

      logger.notify(output)

      retry_on(
        host,
        %(echo "saving snapshot '#{snap}'" > /dev/null),
        max_retries: 30,
        retry_interval: 1,
      )
    end
  end

  # Whether or not a named snapshot exists
  #
  # @param host [Beaker::Host]
  #   The SUT to work on
  #
  # @param snapshot_name [String]
  #   The string to add to the snapshot
  #
  # @return [Boolean]
  def self.exist?(host, name)
    list(host).include?(name)
  end

  # List all snapshots for the given host
  #
  # @parma host [Beaker::Host]
  #   The SUT to work on
  #
  # @return [Array[String]]
  #   A list of snapshot names for the host
  def self.list(host)
    output = []
    vdir = vagrant_dir(host)

    if vdir
      Dir.chdir(vdir) do
        output = `vagrant snapshot list #{host.name}`.lines
        output.map! do |x|
          x.split(%r{^#{host.name}_}).last.split(':').first.delete('==>').strip
        end
      end
    end

    output
  end

  # Restore a snapshot
  #
  # @param host [Beaker::Host]
  #   The SUT to work on
  #
  # @param snapshot_name [String]
  #   The name that was added to the snapshot
  #
  def self.restore(host, snapshot_name)
    return unless enabled?
    vdir = vagrant_dir(host)

    return unless vdir
    Dir.chdir(vdir) do
      snap = "#{host.name}_#{snapshot_name}"

      output = `vagrant snapshot restore #{host.name} "#{snap}" 2>&1`

      if (output =~ %r{error}i) && output.include?('child')
        raise output
      end

      if %r{snapshot.*not found}.match?(output)
        raise output
      end

      logger.notify(output)

      retry_on(
        host,
        %(echo "restoring snapshot '#{snap}'" > /dev/null),
        max_retries: 30,
        retry_interval: 1,
      )
    end
  end

  # Restore all the way back to the base image
  #
  # @param host [Beaker::Host]
  #   The SUT to work on
  #
  def self.restore_to_base(host)
    if exist?(host, BASE_NAME)
      restore(host, BASE_NAME)
    else
      save(host, BASE_NAME)
    end
  end

  def self.enabled?
    enabled = ENV['BEAKER_simp_snapshot'] == 'yes'

    unless enabled
      logger.warn('Snapshotting not enabled, set BEAKER_simp_snapshot=yes to enable')
    end

    enabled
  end

  def self.vagrant_dir(host)
    tgt_dir = nil

    if host&.options && host.options[:hosts_file]
      vdir = File.join('.vagrant', 'beaker_vagrant_files', File.basename(host.options[:hosts_file]))

      if File.directory?(vdir)
        tgt_dir = vdir
      else
        logger.notify("Could not find local vagrant dir at #{vdir}")
      end
    end

    tgt_dir
  end
end
