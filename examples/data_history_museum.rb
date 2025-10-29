#!/usr/bin/env ruby
# frozen_string_literal: true

# Data History Museum (DHM) Asset Monitoring Example
#
# This example monitors the Data History Museum account for asset configuration transactions.
# The DHM is an Algorand project that creates NFTs representing historical data.
#
# Account: ER7AMZRPD5KDVFWTUUVOADSOWM4RQKEEV2EDYRVSA757UHXOIEKGMBQIVU

require "bundler/setup"
require "algokit/subscriber"
require "json"

# Configuration
ALGOD_SERVER = ENV.fetch("ALGOD_SERVER", "https://testnet-api.algonode.cloud")
ALGOD_TOKEN = ENV.fetch("ALGOD_TOKEN", "")
INDEXER_SERVER = ENV.fetch("INDEXER_SERVER", "https://testnet-idx.algonode.cloud")
INDEXER_TOKEN = ENV.fetch("INDEXER_TOKEN", "")
DHM_ADDRESS = "ER7AMZRPD5KDVFWTUUVOADSOWM4RQKEEV2EDYRVSA757UHXOIEKGMBQIVU"

# Watermark persistence (in-memory for this example)
watermark = 0

# Create clients
algod = Algokit::Subscriber::Client::AlgodClient.new(ALGOD_SERVER, token: ALGOD_TOKEN)
indexer = Algokit::Subscriber::Client::IndexerClient.new(INDEXER_SERVER, token: INDEXER_TOKEN)

# Configure subscription
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: "dhm-assets",
      filter: {
        type: "acfg",
        sender: DHM_ADDRESS
      }
    }
  ],
  max_rounds_to_sync: 100,
  max_indexer_rounds_to_sync: 1000,
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::CATCHUP_WITH_INDEXER,
  frequency_in_seconds: 5.0,
  wait_for_block_when_at_tip: true,
  watermark_persistence: {
    get: -> { watermark },
    set: ->(w) { watermark = w }
  }
)

# Create subscriber
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

# Track statistics
stats = {
  created: 0,
  modified: 0,
  destroyed: 0,
  total_transactions: 0
}

# Handle asset configuration transactions
subscriber.on("dhm-assets") do |txn|
  stats[:total_transactions] += 1

  if txn["created-asset-index"]
    stats[:created] += 1
    asset_id = txn["created-asset-index"]
    params = txn.dig("asset-config-transaction", "params")

    puts "\n🎨 Asset Created!"
    puts "  Asset ID: #{asset_id}"
    puts "  Name: #{params["name"]}" if params["name"]
    puts "  Unit: #{params["unit-name"]}" if params["unit-name"]
    puts "  Total: #{params["total"]}" if params["total"]
    puts "  URL: #{params["url"]}" if params["url"]
    puts "  Round: #{txn["confirmed-round"]}"
    puts "  Transaction: #{txn["id"]}"
  elsif txn.dig("asset-config-transaction", "params").nil?
    stats[:destroyed] += 1
    asset_id = txn.dig("asset-config-transaction", "asset-id")

    puts "\n🗑️  Asset Destroyed"
    puts "  Asset ID: #{asset_id}"
    puts "  Round: #{txn["confirmed-round"]}"
  else
    stats[:modified] += 1
    asset_id = txn.dig("asset-config-transaction", "asset-id")

    puts "\n✏️  Asset Modified"
    puts "  Asset ID: #{asset_id}"
    puts "  Round: #{txn["confirmed-round"]}"
  end
end

# Handle batch updates
subscriber.on_batch("dhm-assets") do |transactions|
  puts "\n📦 Batch: #{transactions.length} asset operations" if transactions.length > 1
end

# Monitor poll progress
subscriber.on_poll do |result|
  if result.synced_round_range.any?
    puts "\n📊 Poll Complete"
    puts "  Synced rounds: #{result.synced_round_range.first}..#{result.synced_round_range.last}"
    puts "  Transactions found: #{result.subscribed_transactions.sum { |r| r.transactions.length }}"
    puts "  Current watermark: #{result.new_watermark}"
  end
end

# Handle errors
subscriber.on_error do |error|
  puts "\n❌ Error: #{error.message}"
  puts error.backtrace.first(3).join("\n")
end

# Print startup message
puts "=" * 60
puts "Data History Museum Asset Monitor"
puts "=" * 60
puts "Monitoring account: #{DHM_ADDRESS}"
puts "Starting watermark: #{watermark}"
puts "Press Ctrl+C to stop"
puts "=" * 60

# Handle shutdown
Signal.trap("INT") do
  puts "\n\n🛑 Shutting down..."
  puts "\n📈 Final Statistics:"
  puts "  Total transactions: #{stats[:total_transactions]}"
  puts "  Assets created: #{stats[:created]}"
  puts "  Assets modified: #{stats[:modified]}"
  puts "  Assets destroyed: #{stats[:destroyed]}"
  puts "  Final watermark: #{watermark}"
  puts "\nGoodbye! 👋"
  subscriber.stop("SIGINT")
end

# Start monitoring
subscriber.start
