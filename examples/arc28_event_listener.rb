#!/usr/bin/env ruby
# frozen_string_literal: true

# ARC-28 Event Listener Example
#
# This example demonstrates how to listen for ARC-28 events emitted by smart contracts.
# ARC-28 defines a standard for event logging in Algorand applications.

require "bundler/setup"
require "algokit/subscriber"

# Configuration
ALGOD_SERVER = ENV.fetch("ALGOD_SERVER", "https://testnet-api.algonode.cloud")
INDEXER_SERVER = ENV.fetch("INDEXER_SERVER", "https://testnet-idx.algonode.cloud")

# Example: Monitoring a DEX for Swap events
# Replace with your actual app ID and event definitions
APP_ID = ENV.fetch("APP_ID", "123456").to_i

# Create clients
algod = Algokit::Subscriber::Client::AlgodClient.new(ALGOD_SERVER)
indexer = Algokit::Subscriber::Client::IndexerClient.new(INDEXER_SERVER)

# Define ARC-28 events to listen for
arc28_events = [
  Algokit::Subscriber::Types::Arc28EventGroup.new(
    group_name: "DEX",
    events: [
      {
        name: "Swap",
        args: [
          { name: "sender", type: "address" },
          { name: "amountIn", type: "uint64" },
          { name: "amountOut", type: "uint64" },
          { name: "assetIn", type: "uint64" },
          { name: "assetOut", type: "uint64" }
        ]
      },
      {
        name: "AddLiquidity",
        args: [
          { name: "provider", type: "address" },
          { name: "amount1", type: "uint64" },
          { name: "amount2", type: "uint64" }
        ]
      },
      {
        name: "RemoveLiquidity",
        args: [
          { name: "provider", type: "address" },
          { name: "amount1", type: "uint64" },
          { name: "amount2", type: "uint64" }
        ]
      }
    ]
  )
]

# Watermark
watermark = 0

# Configure subscription
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: "dex-events",
      filter: {
        type: "appl",
        app_id: APP_ID,
        arc28_events: [
          { group_name: "DEX", event_name: "Swap" },
          { group_name: "DEX", event_name: "AddLiquidity" },
          { group_name: "DEX", event_name: "RemoveLiquidity" }
        ]
      }
    }
  ],
  arc28_events: arc28_events,
  max_rounds_to_sync: 10,
  frequency_in_seconds: 2.0,
  watermark_persistence: {
    get: -> { watermark },
    set: ->(w) { watermark = w }
  }
)

# Create subscriber
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

# Handle DEX events
subscriber.on("dex-events") do |txn|
  events = txn["arc28-events"] || []

  events.each do |event|
    case event.event_name
    when "Swap"
      puts "\n🔄 Swap Event"
      puts "  Sender: #{event.args["sender"]}"
      puts "  Amount In: #{event.args["amountIn"]}"
      puts "  Amount Out: #{event.args["amountOut"]}"
      puts "  Asset In: #{event.args["assetIn"]}"
      puts "  Asset Out: #{event.args["assetOut"]}"
      puts "  Round: #{txn["confirmed-round"]}"

    when "AddLiquidity"
      puts "\n➕ Add Liquidity Event"
      puts "  Provider: #{event.args["provider"]}"
      puts "  Amount 1: #{event.args["amount1"]}"
      puts "  Amount 2: #{event.args["amount2"]}"
      puts "  Round: #{txn["confirmed-round"]}"

    when "RemoveLiquidity"
      puts "\n➖ Remove Liquidity Event"
      puts "  Provider: #{event.args["provider"]}"
      puts "  Amount 1: #{event.args["amount1"]}"
      puts "  Amount 2: #{event.args["amount2"]}"
      puts "  Round: #{txn["confirmed-round"]}"
    end
  end
end

# Print startup message
puts "=" * 60
puts "ARC-28 Event Listener"
puts "=" * 60
puts "Application ID: #{APP_ID}"
puts "Listening for: Swap, AddLiquidity, RemoveLiquidity events"
puts "Press Ctrl+C to stop"
puts "=" * 60

# Handle shutdown
Signal.trap("INT") do
  puts "\n\n👋 Shutting down..."
  subscriber.stop
end

# Start
subscriber.start
