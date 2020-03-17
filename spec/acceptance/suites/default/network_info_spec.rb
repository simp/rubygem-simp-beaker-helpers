require 'spec_helper_acceptance'

hosts.each do |host|
  describe '#host_networks' do
    it 'returns networks' do
      networks = host_networks(host)
      puts "networks = #{networks.inspect}"

      expect(networks).to_not be_nil
      expect(networks).to be_an(Array)
      expect(networks).to_not be_empty
    end
  end

  describe '#internal_network_info' do
    it 'returns internal network info' do
      internal_network = internal_network_info(host)
      puts "internal_network = #{internal_network.inspect}"

      expect(internal_network).to_not be_nil
      expect(internal_network).to be_a(Hash)
      expect(internal_network).to_not be_empty

      [:interface, :ip, :netmask].each do |key|
        expect(internal_network[key]).to_not be_nil
        expect(internal_network[key].strip).to_not be_empty
      end
    end
  end
end
