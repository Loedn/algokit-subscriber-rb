require 'bundler/setup'
require 'webmock'
require 'faraday'

include WebMock::API
WebMock.enable!

stub_request(:get, "https://testnet-api.algonode.cloud/v2/status")
  .to_return(status: 200, body: '{"last-round": 123}')

conn = Faraday.new(url: 'https://testnet-api.algonode.cloud/v2')
response = conn.get('/status')
puts "Status: #{response.status}"
puts "Body: #{response.body}"
