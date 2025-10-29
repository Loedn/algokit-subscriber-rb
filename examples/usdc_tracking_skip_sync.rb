#!/usr/bin/env ruby
# frozen_string_literal: true

# USDC Transaction Tracking - Skip Sync Newest (Algod Only)
#
# This example demonstrates using SKIP_SYNC_NEWEST behavior with algod only.
# SKIP_SYNC_NEWEST jumps immediately to the latest round and starts monitoring
# from there, ignoring all historical transactions. This is useful when you only
# care about NEW transactions going forward, not historical data.

# Don't use bundler/setup to avoid gemspec validation issues during development
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "algokit/subscriber"
require "json"

# Configuration
ALGOD_SERVER = ENV.fetch("ALGOD_SERVER", "https://testnet-api.algonode.cloud")
ALGOD_TOKEN = ENV.fetch("ALGOD_TOKEN", "")

# USDC on TestNet (change for MainNet)
USDC_ASSET_ID = 10_458_941

# Create algod client ONLY (no indexer needed)
algod = Algokit::Subscriber::Client::AlgodClient.new(ALGOD_SERVER, token: ALGOD_TOKEN)

# Configure subscription with SKIP_SYNC_NEWEST
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: "usdc-transfers",
      filter: {
        type: "axfer",
        asset_id: USDC_ASSET_ID,
        min_amount: 1
      }
    },
    {
      name: "usdc-opt-ins",
      filter: {
        type: "axfer",
        asset_id: USDC_ASSET_ID,
        min_amount: 0 # Opt-ins have 0 amount
      },
      mapper: ->(txn) do
        # Custom mapper to flag opt-ins vs transfers
        amount = txn.dig("asset-transfer-transaction", "amount") || 0
        receiver = txn.dig("asset-transfer-transaction", "receiver")
        sender = txn["sender"]
        
        {
          id: txn["id"],
          round: txn["confirmed-round"],
          is_opt_in: amount == 0 && receiver == sender,
          amount: amount,
          sender: sender,
          receiver: receiver
        }
      end
    }
  ],
  max_rounds_to_sync: 10, # Process 10 rounds at a time
  # SKIP_SYNC_NEWEST: Always jump to the latest round, never sync old data
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST,
  frequency_in_seconds: 1.5,
  wait_for_block_when_at_tip: true # Use low-latency wait-for-block mode
)

# Create subscriber with algod only
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

# Track statistics
stats = {
  transfers: 0,
  opt_ins: 0,
  total_volume: 0,
  start_time: Time.now,
  start_round: nil
}

# Helper to format USDC amount (6 decimals)
def format_usdc(microusdc)
  (microusdc / 1_000_000.0).round(6)
end

# Handle USDC transfers
subscriber.on("usdc-transfers") do |txn|
  stats[:transfers] += 1
  amount = txn.dig("asset-transfer-transaction", "amount") || 0
  stats[:total_volume] += amount

  sender = txn["sender"]
  receiver = txn.dig("asset-transfer-transaction", "receiver")

  # Determine transfer type
  if amount == 0 && receiver == sender
    # This is an opt-in (0 amount to self)
    puts "\n🔵 USDC Opt-In"
    puts "  Account: #{sender[0..10]}...#{sender[-10..]}"
  else
    # This is a transfer
    puts "\n💵 USDC Transfer"
    puts "  Amount: #{format_usdc(amount)} USDC"
    puts "  From: #{sender[0..10]}...#{sender[-10..]}"
    puts "  To: #{receiver[0..10]}...#{receiver[-10..]}" if receiver
  end
  
  puts "  Round: #{txn["confirmed-round"]}"
  puts "  TX: #{txn["id"][0..20]}..."
end

# Handle opt-ins with custom mapping
subscriber.on("usdc-opt-ins") do |mapped_txn|
  if mapped_txn[:is_opt_in]
    stats[:opt_ins] += 1
    puts "\n✅ Account Opted In to USDC"
    puts "  Account: #{mapped_txn[:sender][0..10]}...#{mapped_txn[:sender][-10..]}"
    puts "  Round: #{mapped_txn[:round]}"
    puts "  TX: #{mapped_txn[:id][0..20]}..."
  end
end

# Track when we start monitoring
subscriber.on_before_poll do |watermark, current_round|
  if stats[:start_round].nil?
    stats[:start_round] = current_round
    puts "\n🚀 Started monitoring from round #{current_round}"
    puts "⏭️  All historical data skipped (SKIP_SYNC_NEWEST mode)"
  end
end

# Show sync progress
subscriber.on_poll do |result|
  if result.synced_round_range.any?
    total_txns = result.subscribed_transactions.sum { |r| r.transactions.length }
    if total_txns > 0
      range = result.synced_round_range
      puts "\n📦 Processed rounds #{range.first}..#{range.last} (#{total_txns} USDC txns)"
    end
  end
end

# Handle errors
subscriber.on_error do |error|
  puts "\n❌ Error: #{error.message}"
  puts error.backtrace.first(3).join("\n") if ENV["DEBUG"]
end

# Print startup message
puts "=" * 75
puts "USDC Transaction Tracker - SKIP SYNC NEWEST (Algod Only)"
puts "=" * 75
puts "Asset ID: #{USDC_ASSET_ID}"
puts "Mode: SKIP_SYNC_NEWEST + Algod Only"
puts ""
puts "This mode:"
puts "  ✓ Jumps immediately to the latest round"
puts "  ✓ Ignores all historical transactions"
puts "  ✓ Only tracks NEW transactions from now on"
puts "  ✓ Perfect for real-time monitoring without catchup"
puts ""
puts "Press Ctrl+C to stop"
puts "=" * 75

# Handle shutdown
Signal.trap("INT") do
  duration = Time.now - stats[:start_time]
  
  puts "\n\n🛑 Shutting down..."
  puts "\n📊 Session Statistics:"
  puts "  Runtime: #{duration.round(1)} seconds"
  puts "  Started at round: #{stats[:start_round]}"
  puts "  USDC Transfers: #{stats[:transfers]}"
  puts "  USDC Opt-ins: #{stats[:opt_ins]}"
  puts "  Total Volume: #{format_usdc(stats[:total_volume])} USDC"
  
  if stats[:transfers] > 0 || stats[:opt_ins] > 0
    rate = ((stats[:transfers] + stats[:opt_ins]) / duration * 60).round(2)
    puts "  Detection Rate: #{rate} txns/minute"
  end
  
  puts "\n💡 Note: In SKIP_SYNC_NEWEST mode, the subscriber never catches up"
  puts "   on missed rounds. If you stop and restart, it jumps to the latest"
  puts "   round again, skipping any transactions that occurred while stopped."
  
  puts "\nGoodbye! 👋"
  subscriber.stop("SIGINT")
end

# Start monitoring
subscriber.start
