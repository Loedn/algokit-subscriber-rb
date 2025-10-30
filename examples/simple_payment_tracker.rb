#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple Payment Tracker Example
#
# This example demonstrates basic usage of algokit-subscriber
# by tracking payment transactions above a certain threshold.

require "bundler/setup"
require "algokit/subscriber"

# Configuration
ALGOD_SERVER = ENV.fetch("ALGOD_SERVER", "https://mainnet-api.algonode.cloud")
INDEXER_SERVER = ENV.fetch("INDEXER_SERVER", "https://mainnet-idx.algonode.cloud")
MIN_AMOUNT = 1_000_000 # 1 Algo (in microAlgos)

# Create clients
algod = Algokit::Subscriber::Client::AlgodClient.new(ALGOD_SERVER)
indexer = Algokit::Subscriber::Client::IndexerClient.new(INDEXER_SERVER)

# Simple in-memory watermark
watermark = 0

# Configure subscription
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: "large-payments",
      filter: {
        type: "pay",
        min_amount: MIN_AMOUNT
      }
    }
  ],
  max_rounds_to_sync: 5,
  frequency_in_seconds: 3.0,
  watermark_persistence: {
    get: -> { watermark },
    set: ->(w) { watermark = w }
  }
)

# Create subscriber
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

# Helper to convert microAlgos to Algos
def to_algos(microalgos)
  (microalgos / 1_000_000.0).round(6)
end

# Count transactions
count = 0

# Handle each payment
subscriber.on("large-payments") do |txn|
  count += 1
  amount = txn.dig("payment-transaction", "amount")
  sender = txn["sender"]
  receiver = txn.dig("payment-transaction", "receiver")

  puts "\n💰 Payment ##{count}"
  puts "  Amount: #{to_algos(amount)} ALGO"
  puts "  From: #{sender[0..15]}..."
  puts "  To: #{receiver[0..15]}..."
  puts "  Round: #{txn["confirmed-round"]}"
end

# Print startup message
puts "=" * 50
puts "Simple Payment Tracker"
puts "=" * 50
puts "Tracking payments > #{to_algos(MIN_AMOUNT)} ALGO"
puts "Press Ctrl+C to stop"
puts "=" * 50

# Handle shutdown
Signal.trap("INT") do
  puts "\n\n👋 Found #{count} payments"
  subscriber.stop
end

# Start
subscriber.start
