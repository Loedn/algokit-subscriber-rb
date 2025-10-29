#!/usr/bin/env ruby
# frozen_string_literal: true

# USDC Transfer Monitoring Example
#
# This example monitors USDC (TestNet Asset ID: 10458941) transfers in real-time.
# It demonstrates filtering by asset ID and calculating balance changes.

# Don't use bundler/setup to avoid gemspec validation issues during development
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "algokit/subscriber"
require "json"

# Configuration
ALGOD_SERVER = ENV.fetch("ALGOD_SERVER", "https://testnet-api.algonode.cloud")
ALGOD_TOKEN = ENV.fetch("ALGOD_TOKEN", "")
INDEXER_SERVER = ENV.fetch("INDEXER_SERVER", "https://testnet-idx.algonode.cloud")
INDEXER_TOKEN = ENV.fetch("INDEXER_TOKEN", "")

# USDC on TestNet (change for MainNet)
USDC_ASSET_ID = 10_458_941

# Watermark persistence (file-based for this example)
WATERMARK_FILE = "usdc_watermark.txt"

def load_watermark
  File.read(WATERMARK_FILE).to_i
rescue Errno::ENOENT
  0
end

def save_watermark(watermark)
  File.write(WATERMARK_FILE, watermark.to_s)
end

# Create clients
algod = Algokit::Subscriber::Client::AlgodClient.new(ALGOD_SERVER, token: ALGOD_TOKEN)
# Indexer is optional - subscriber works with algod only for real-time monitoring
indexer = Algokit::Subscriber::Client::IndexerClient.new(INDEXER_SERVER, token: INDEXER_TOKEN)

# Configure subscription
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: "usdc-transfers",
      filter: {
        type: "axfer",
        asset_id: USDC_ASSET_ID,
        min_amount: 1 # Only transfers with amount > 0
      }
    },
    {
      name: "large-usdc-transfers",
      filter: {
        type: "axfer",
        asset_id: USDC_ASSET_ID,
        min_amount: 1_000_000 # 1 USDC (6 decimals)
      }
    }
  ],
  max_rounds_to_sync: 10,
  max_indexer_rounds_to_sync: 500,
  # Use SYNC_OLDEST_START_NOW to skip historical data and start from current round
  # This prevents waiting for millions of rounds before USDC was created
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST_START_NOW,
  frequency_in_seconds: 2.0,
  wait_for_block_when_at_tip: true,
  watermark_persistence: {
    get: -> { load_watermark },
    set: ->(w) { save_watermark(w) }
  }
)

# Create subscriber
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

# Track statistics
stats = {
  total_transfers: 0,
  large_transfers: 0,
  total_volume: 0
}

# Helper to format USDC amount (6 decimals)
def format_usdc(microusdc)
  (microusdc / 1_000_000.0).round(6)
end

# Handle all USDC transfers
subscriber.on("usdc-transfers") do |txn|
  stats[:total_transfers] += 1
  amount = txn.dig("asset-transfer-transaction", "amount") || 0
  stats[:total_volume] += amount

  sender = txn["sender"]
  receiver = txn.dig("asset-transfer-transaction", "receiver")

  puts "\n💵 USDC Transfer"
  puts "  Amount: #{format_usdc(amount)} USDC"
  puts "  From: #{sender[0..10]}...#{sender[-10..]}"
  puts "  To: #{receiver[0..10]}...#{receiver[-10..]}"
  puts "  Round: #{txn["confirmed-round"]}"
  puts "  TX: #{txn["id"][0..15]}..."
end

# Handle large USDC transfers
subscriber.on("large-usdc-transfers") do |txn|
  stats[:large_transfers] += 1
  amount = txn.dig("asset-transfer-transaction", "amount") || 0

  puts "\n🚨 LARGE USDC TRANSFER!"
  puts "  Amount: #{format_usdc(amount)} USDC"
  puts "  From: #{txn["sender"]}"
  puts "  To: #{txn.dig("asset-transfer-transaction", "receiver")}"
  puts "  Transaction: #{txn["id"]}"
end

# Monitor poll progress
subscriber.on_poll do |result|
  if result.synced_round_range.any?
    total_txns = result.subscribed_transactions.sum { |r| r.transactions.length }
    if total_txns.positive?
      puts "\n✅ Synced rounds #{result.synced_round_range.first}..#{result.synced_round_range.last} (#{total_txns} txns)"
    end
  end
end

# Handle errors
subscriber.on_error do |error|
  puts "\n❌ Error: #{error.message}"
end

# Print startup message
puts "=" * 70
puts "USDC Transfer Monitor (TestNet)"
puts "=" * 70
puts "Asset ID: #{USDC_ASSET_ID}"
puts "Starting watermark: #{load_watermark}"
puts "Monitoring all transfers > 0 and highlighting transfers > 1 USDC"
puts "Press Ctrl+C to stop"
puts "=" * 70

# Handle shutdown
Signal.trap("INT") do
  puts "\n\n🛑 Shutting down..."
  puts "\n📈 Session Statistics:"
  puts "  Total transfers: #{stats[:total_transfers]}"
  puts "  Large transfers (>1 USDC): #{stats[:large_transfers]}"
  puts "  Total volume: #{format_usdc(stats[:total_volume])} USDC"
  puts "  Final watermark: #{load_watermark}"
  puts "\nGoodbye! 👋"
  subscriber.stop("SIGINT")
end

# Start monitoring
subscriber.start
