module Simp; end
module Simp::BeakerHelpers; end

module Simp::BeakerHelpers::Network

  # @returns array of IPV4 networks configured on a host or nil
  #   if none can be determined
  #
  # NOTE:
  # - Result can be used for simp_options::trusted_nets in a test.
  # - Uses the modern 'networking' fact from the puppet-agent RPM.
  #
  # @param host [Host] the host whose networks info is to be retrieved
  #
  def host_networks(host)
    require 'json'
    require 'ipaddr'
    networks = nil
    networking = JSON.load(on(host, 'facter --json networking').stdout)
    if networking.key?('networking') && networking['networking'].key?('interfaces')
      networking['networking']['interfaces'].delete_if { |key,value| key == 'lo' }
      networks = networking['networking']['interfaces'].map do |key,value|
        net_mask = IPAddr.new(value['netmask']).to_i.to_s(2).count('1')
        "#{value['network']}/#{net_mask}"
      end
    end

    networks
  end

  # @returns the internal IPV4 network info for a host or nil if
  #   none can be determined
  #
  # NOTES:
  # - Uses the modern 'networking' fact from the puppet-agent RPM.
  # - This method ASSUMES the first non-loopback interface without DHCP
  #   configured or with DHCP that does not matches the outermost 'dhcp'
  #   key is the interface used for the internal network.
  #
  # @param host [Host] the host whose internal network info is to be retrieved
  #
  def internal_network_info(host)
    networking = JSON.load(on(host, 'facter --json networking').stdout)
    internal_ip_info = nil
    if networking.key?('networking') && networking['networking'].key?('interfaces')
      main_dhcp = networking['networking']['dhcp']
      networking['networking']['interfaces'].each do |interface,settings|
        next if interface == 'lo'
        if ( ! settings.has_key?('dhcp') || (settings['dhcp'] != main_dhcp ) )
          internal_ip_info = {
            :interface => interface,
            :ip        => settings['ip'],
            :netmask   => settings['netmask']
          }
          break
        end
      end
    end

    internal_ip_info
  end
end
