skips = {
  'V-72209' => 'Cannot guarantee a remote syslog server during test'
}
overrides = [ 'V-72091' ]
subsystems = []

require_controls 'disa_stig-el7-baseline' do
  skips.each_pair do |ctrl, reason|
    control ctrl do
      describe "Skip #{ctrl}" do
        skip "Reason: #{skips[ctrl]}" do
        end
      end
    end
  end

  @conf['profile'].info[:controls].each do |ctrl|
    next if (overrides + skips.keys).include?(ctrl[:id])

    if subsystems.empty?
      control ctrl[:id]
    else
      tags = ctrl[:tags]
      if tags && tags[:subsystems]
        subsystems.each do |subsystem|
          if tags[:subsystems].include?(subsystem)
            control ctrl[:id]
          end
        end
      end
    end
  end

  ## Overrides ##

  # There's no email server to send anything to by default so syslog is a safer
  # default for processing.
  control 'V-72091' do
    overrides << self.to_s

    describe auditd_conf do
      its('space_left_action.downcase') { should cmp 'syslog' }
    end
  end
end
