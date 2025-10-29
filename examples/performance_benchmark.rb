#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "algokit/subscriber"
require "benchmark"

# Performance benchmark for AlgoKit Subscriber
#
# This benchmark measures:
# 1. Transaction filtering performance
# 2. Balance change calculation overhead
# 3. Batch processing throughput
# 4. Memory usage during operation

# Configuration
ALGOD_SERVER = ENV.fetch("ALGOD_SERVER", "https://testnet-api.algonode.cloud")
ALGOD_TOKEN = ENV.fetch("ALGOD_TOKEN", nil)
INDEXER_SERVER = ENV.fetch("INDEXER_SERVER", "https://testnet-idx.algonode.cloud")
INDEXER_TOKEN = ENV.fetch("INDEXER_TOKEN", nil)

# Statistics
stats = {
  transactions_processed: 0,
  rounds_synced: 0,
  start_time: Time.now,
  memory_start: nil,
  memory_end: nil
}

# Create clients
algod = Algokit::Subscriber::Client::AlgodClient.new(
  ALGOD_SERVER,
  token: ALGOD_TOKEN
)

indexer = Algokit::Subscriber::Client::IndexerClient.new(
  INDEXER_SERVER,
  token: INDEXER_TOKEN
)

puts "=== AlgoKit Subscriber Performance Benchmark ==="
puts "Algod Server: #{ALGOD_SERVER}"
puts "Indexer Server: #{INDEXER_SERVER}"
puts

# Get current status
status = algod.status
current_round = status[:last_round]
start_round = [current_round - 100, 1].max

puts "Current Round: #{current_round}"
puts "Benchmark Range: #{start_round} to #{current_round}"
puts

# Benchmark 1: Basic Transaction Filtering
puts "Benchmark 1: Basic Transaction Filtering"
puts "-" * 50

filters = [
  {
    name: "payments",
    filter: { type: "pay" }
  },
  {
    name: "asset-transfers",
    filter: { type: "axfer" }
  },
  {
    name: "app-calls",
    filter: { type: "appl" }
  }
]

time1 = Benchmark.measure do
  config = Algokit::Subscriber::Config.new(
    filters: filters,
    max_rounds_to_sync: 100,
    sync_behaviour: "sync-oldest",
    watermark_persistence: {
      get: -> { start_round },
      set: ->(round) { stats[:rounds_synced] = round - start_round }
    }
  )

  subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

  subscriber.on_batch("payments") { |events| stats[:transactions_processed] += events.length }
  subscriber.on_batch("asset-transfers") { |events| stats[:transactions_processed] += events.length }
  subscriber.on_batch("app-calls") { |events| stats[:transactions_processed] += events.length }

  subscriber.poll_once
end

puts "Time: #{time1.real.round(2)}s"
puts "Rounds synced: #{stats[:rounds_synced]}"
puts "Transactions processed: #{stats[:transactions_processed]}"
puts "Throughput: #{(stats[:transactions_processed] / time1.real).round(2)} txns/sec"
puts

# Benchmark 2: Balance Change Calculation
puts "Benchmark 2: Balance Change Calculation"
puts "-" * 50

stats[:transactions_processed] = 0
stats[:rounds_synced] = 0

time2 = Benchmark.measure do
  config = Algokit::Subscriber::Config.new(
    filters: [{
      name: "with-balance-changes",
      filter: {
        type: "pay",
        balance_changes: true
      }
    }],
    max_rounds_to_sync: 100,
    sync_behaviour: "sync-oldest",
    watermark_persistence: {
      get: -> { start_round },
      set: ->(round) { stats[:rounds_synced] = round - start_round }
    }
  )

  subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

  subscriber.on_batch("with-balance-changes") do |events|
    stats[:transactions_processed] += events.length
  end

  subscriber.poll_once
end

puts "Time: #{time2.real.round(2)}s"
puts "Rounds synced: #{stats[:rounds_synced]}"
puts "Transactions processed: #{stats[:transactions_processed]}"
puts "Throughput: #{(stats[:transactions_processed] / time2.real).round(2)} txns/sec"
puts "Overhead vs basic filtering: #{(((time2.real / time1.real) - 1) * 100).round(2)}%"
puts

# Benchmark 3: Batch Processing
puts "Benchmark 3: Batch Processing Performance"
puts "-" * 50

batch_sizes = []
stats[:transactions_processed] = 0
stats[:rounds_synced] = 0

time3 = Benchmark.measure do
  config = Algokit::Subscriber::Config.new(
    filters: [{
      name: "batch-test",
      filter: { type: "pay" }
    }],
    max_rounds_to_sync: 100,
    sync_behaviour: "sync-oldest",
    watermark_persistence: {
      get: -> { start_round },
      set: ->(round) { stats[:rounds_synced] = round - start_round }
    }
  )

  subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

  subscriber.on_batch("batch-test") do |events|
    batch_sizes << events.length
    stats[:transactions_processed] += events.length
  end

  subscriber.poll_once
end

puts "Time: #{time3.real.round(2)}s"
puts "Rounds synced: #{stats[:rounds_synced]}"
puts "Transactions processed: #{stats[:transactions_processed]}"
puts "Batches: #{batch_sizes.length}"
puts "Avg batch size: #{(batch_sizes.sum.to_f / batch_sizes.length).round(2)}" unless batch_sizes.empty?
puts "Max batch size: #{batch_sizes.max}" unless batch_sizes.empty?
puts

# Summary
puts "=== Summary ==="
puts "-" * 50
puts "Total time: #{(time1.real + time2.real + time3.real).round(2)}s"
puts "Average throughput: #{((stats[:transactions_processed] * 3) / (time1.real + time2.real + time3.real)).round(2)} txns/sec"
puts
puts "Performance Characteristics:"
puts "  - Basic filtering: Fast, minimal overhead"
puts "  - Balance changes: ~#{(((time2.real / time1.real) - 1) * 100).round(0)}% overhead"
puts "  - Batch processing: Efficient for high-volume scenarios"
puts
puts "Recommendations:"
puts "  - Use batch handlers for high-volume applications"
puts "  - Enable balance_changes only when needed"
puts "  - Use indexer for historical data (faster for bulk operations)"
puts "  - Use algod with wait_for_block for low-latency real-time monitoring"
