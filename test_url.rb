require 'faraday'

# Test 1: Path starting with /
conn1 = Faraday.new(url: 'https://testnet-api.algonode.cloud/v2')
puts "Base URL: https://testnet-api.algonode.cloud/v2"
puts "Path: /status"
puts "Result: Would request #{conn1.build_url('/status')}"
puts

# Test 2: Path without leading /
conn2 = Faraday.new(url: 'https://testnet-api.algonode.cloud/v2')
puts "Base URL: https://testnet-api.algonode.cloud/v2"
puts "Path: status"
puts "Result: Would request #{conn2.build_url('status')}"
