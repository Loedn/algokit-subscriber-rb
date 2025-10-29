#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple example to test the gem against Algorand TestNet
# This demonstrates basic usage of the AlgodClient and IndexerClient

require "bundler/setup"
require "algokit/subscriber"

puts "AlgoKit Subscriber Ruby - Simple Test\n\n"

# Use public TestNet nodes (no authentication required)
ALGOD_SERVER = "https://testnet-api.algonode.cloud"
INDEXER_SERVER = "https://testnet-idx.algonode.cloud"

# Test AlgodClient
puts "=" * 60
puts "Testing AlgodClient"
puts "=" * 60

algod = Algokit::Subscriber::Client::AlgodClient.new(ALGOD_SERVER)

print "Fetching current status... "
status_data = algod.status
status = Algokit::Subscriber::Models::Status.new(status_data)
puts "✓"

puts "\nCurrent Status:"
puts "  Last Round: #{status.last_round}"
puts "  Time Since Last Round: #{status.time_since_last_round_seconds&.round(2)}s"
puts "  Caught Up: #{status.caught_up? ? "Yes" : "No"}"
puts "  Catchup Time: #{status.catchup_time}"

# Fetch a recent block
block_round = status.last_round - 10 # Get a block from 10 rounds ago
print "\nFetching block #{block_round}... "
block_data = algod.block(block_round)
block = Algokit::Subscriber::Models::Block.new(block_data)
puts "✓"

puts "\nBlock Information:"
puts "  Round: #{block.round}"
puts "  Timestamp: #{Time.at(block.timestamp)}"
puts "  Genesis ID: #{block.genesis_id}"
puts "  Transaction Counter: #{block.txn_counter}"
puts "  Proposer: #{block.proposer || "N/A"}"

# Test IndexerClient
puts "\n#{"=" * 60}"
puts "Testing IndexerClient"
puts "=" * 60

indexer = Algokit::Subscriber::Client::IndexerClient.new(INDEXER_SERVER)

# Search for recent transactions
search_start = status.last_round - 100
search_end = status.last_round - 50

print "\nSearching for transactions (rounds #{search_start}-#{search_end})... "
result = indexer.search_transactions(
  min_round: search_start,
  max_round: search_end,
  limit: 10
)
puts "✓"

puts "\nSearch Results:"
puts "  Current Round: #{result["current-round"]}"
puts "  Transactions Found: #{result["transactions"].length}"
puts "  Has More Pages: #{result["next-token"] ? "Yes" : "No"}"

if result["transactions"].any?
  puts "\nFirst Transaction:"
  txn = Algokit::Subscriber::Models::Transaction.new(result["transactions"].first)
  puts "  ID: #{txn.id}"
  puts "  Type: #{txn.type}"
  puts "  Sender: #{txn.sender}"
  puts "  Round: #{txn.round}"
  puts "  Fee: #{txn.fee} microAlgos"

  case txn.type
  when "pay"
    puts "  Payment: #{txn.amount} microAlgos to #{txn.receiver}"
  when "axfer"
    puts "  Asset Transfer: #{txn.asset_amount} units of asset #{txn.asset_id}"
  when "appl"
    puts "  Application Call: App ID #{txn.application_id}"
  when "acfg"
    puts "  Asset Config: #{txn.created_asset? ? "Created" : "Modified"} asset"
  end
end

# Search for payment transactions specifically
print "\nSearching for payment transactions only... "
payments = indexer.search_transactions(
  min_round: search_start,
  max_round: search_end,
  tx_type: "pay",
  limit: 5
)
puts "✓"

puts "  Found #{payments["transactions"].length} payment transactions"

puts "\n#{"=" * 60}"
puts "All tests completed successfully! ✓"
puts "=" * 60
puts "\nThe gem is working correctly with Algorand TestNet."
puts "You can now use it to build transaction subscribers and indexers."
