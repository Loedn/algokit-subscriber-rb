# Quick Reference

A cheat sheet for common AlgoKit Subscriber tasks.

## Installation

```bash
gem install algokit-subscriber
# or
bundle add algokit-subscriber
```

## Basic Setup

```ruby
require 'algokit/subscriber'

# Create clients
algod = Algokit::Subscriber::Client::AlgodClient.new('https://testnet-api.algonode.cloud')
indexer = Algokit::Subscriber::Client::IndexerClient.new('https://testnet-idx.algonode.cloud')

# Configure subscription
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    { name: 'payments', filter: { type: 'pay' } }
  ]
)

# Create subscriber
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

# Add handler
subscriber.on('payments') { |txn| puts txn['id'] }

# Start
subscriber.start
```

## Common Filters

### Payment Filters

```ruby
# All payments
{ type: 'pay' }

# Payments over 1 ALGO
{ type: 'pay', min_amount: 1_000_000 }

# Payments to specific address
{ type: 'pay', receiver: 'ADDRESS' }

# Payments from specific address
{ type: 'pay', sender: 'ADDRESS' }

# Payments in amount range
{ type: 'pay', min_amount: 1_000_000, max_amount: 10_000_000 }
```

### Asset Filters

```ruby
# All asset transfers
{ type: 'axfer' }

# Specific asset transfers
{ type: 'axfer', asset_id: 10458941 }

# Asset creation
{ type: 'acfg', asset_create: true }

# Asset transfers over amount
{ type: 'axfer', asset_id: 10458941, min_amount: 1_000_000 }
```

### Application Filters

```ruby
# All app calls
{ type: 'appl' }

# Specific app calls
{ type: 'appl', app_id: 123456 }

# App creation
{ type: 'appl', app_create: true }

# Specific method calls
{ type: 'appl', app_id: 123456, method_signature: 'swap(uint64,uint64)uint64' }
```

### Balance Change Filters

```ruby
# Track address balance changes
{
  balance_changes: [
    { address: 'ADDRESS', min_absolute_amount: 1_000_000 }
  ]
}

# Track specific asset
{
  balance_changes: [
    { address: 'ADDRESS', asset_id: 10458941, min_amount: 1_000_000 }
  ]
}

# Track only deposits
{
  balance_changes: [
    { address: 'ADDRESS', roles: ['Receiver'], min_amount: 1 }
  ]
}
```

## Event Handlers

```ruby
# Single transaction handler
subscriber.on('filter-name') do |txn|
  puts "Transaction: #{txn['id']}"
end

# Batch handler
subscriber.on_batch('filter-name') do |transactions|
  puts "Batch of #{transactions.length} transactions"
end

# Before poll handler
subscriber.on_before_poll do |watermark, current_round|
  puts "Polling: #{watermark} -> #{current_round}"
end

# After poll handler
subscriber.on_poll do |result|
  puts "Synced #{result.rounds_synced} rounds"
end

# Error handler
subscriber.on_error do |error|
  puts "Error: #{error.message}"
end
```

## Sync Behaviors

```ruby
# Use indexer for fast catchup (default)
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::CATCHUP_WITH_INDEXER

# Skip history, start now
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST

# Skip history on first run, catch up on restart
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST_START_NOW

# Always sync from oldest
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST

# Fail if behind
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::FAIL
```

## Watermark Persistence

```ruby
# File-based
watermark_persistence: {
  get: -> { File.read('watermark.txt').to_i rescue 0 },
  set: ->(w) { File.write('watermark.txt', w.to_s) }
}

# Redis
watermark_persistence: {
  get: -> { redis.get('watermark').to_i },
  set: ->(w) { redis.set('watermark', w) }
}

# Database (ActiveRecord)
watermark_persistence: {
  get: -> { Watermark.last&.round || 0 },
  set: ->(w) { Watermark.create!(round: w) }
}
```

## Access Transaction Data

```ruby
subscriber.on('filter-name') do |txn|
  # Common fields
  txn['id']                    # Transaction ID
  txn['sender']                # Sender address
  txn['tx-type']               # Transaction type
  txn['confirmed-round']       # Round number
  txn['fee']                   # Fee in microAlgos
  txn['note']                  # Note (base64)
  
  # Payment specific
  txn.dig('payment-transaction', 'amount')    # Amount
  txn.dig('payment-transaction', 'receiver')  # Receiver
  
  # Asset transfer specific
  txn.dig('asset-transfer-transaction', 'asset-id')  # Asset ID
  txn.dig('asset-transfer-transaction', 'amount')    # Amount
  txn.dig('asset-transfer-transaction', 'receiver')  # Receiver
  
  # Application call specific
  txn.dig('application-transaction', 'application-id')     # App ID
  txn.dig('application-transaction', 'application-args')   # Arguments
  txn.dig('application-transaction', 'on-completion')      # OnComplete
  
  # Inner transactions
  txn['inner-txns']            # Array of inner transactions
  
  # Balance changes (if enabled)
  txn['balance-changes']       # Array of BalanceChange objects
  
  # ARC-28 events (if enabled)
  txn['arc28-events']          # Array of Arc28Event objects
end
```

## Control Flow

```ruby
# Start continuous polling
subscriber.start

# Start with custom inspection
subscriber.start(->(result) { puts "Custom: #{result.rounds_synced}" })

# Start without logs
subscriber.start(suppress_log: true)

# Single poll
result = subscriber.poll_once

# Stop
subscriber.stop('Reason')

# Check if running
subscriber.running?  # => true/false

# Get current watermark
subscriber.watermark  # => 12345
```

## Configuration Options

```ruby
Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [],                          # Transaction filters (required)
  arc28_events: [],                     # ARC-28 event definitions
  max_rounds_to_sync: 100,              # Max rounds per algod poll
  max_indexer_rounds_to_sync: 1000,    # Max rounds per indexer query
  sync_behaviour: 'catchup-with-indexer', # Sync strategy
  frequency_in_seconds: 1.0,            # Polling frequency
  wait_for_block_when_at_tip: true,    # Low-latency mode at tip
  watermark_persistence: nil            # Watermark storage
)
```

## Environment Variables

```ruby
# Load from environment
algod = Algokit::Subscriber::Client::AlgodClient.new(
  ENV['ALGOD_SERVER'] || 'https://testnet-api.algonode.cloud',
  token: ENV['ALGOD_TOKEN']
)

indexer = Algokit::Subscriber::Client::IndexerClient.new(
  ENV['INDEXER_SERVER'] || 'https://testnet-idx.algonode.cloud',
  token: ENV['INDEXER_TOKEN']
)
```

## Graceful Shutdown

```ruby
# Handle SIGINT (Ctrl+C)
Signal.trap('INT') do
  puts "\nShutting down..."
  subscriber.stop('User interrupted')
  exit 0
end

subscriber.start
```

## Common Patterns

### Track Specific Address Activity

```ruby
WALLET = 'YOUR_ADDRESS'

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    { name: 'incoming', filter: { type: 'pay', receiver: WALLET } },
    { name: 'outgoing', filter: { type: 'pay', sender: WALLET } }
  ]
)

subscriber.on('incoming') { |txn| puts "Received payment" }
subscriber.on('outgoing') { |txn| puts "Sent payment" }
```

### Monitor Multiple Assets

```ruby
USDC = 10458941
TOKEN = 123456

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    { name: 'usdc', filter: { type: 'axfer', asset_id: USDC } },
    { name: 'token', filter: { type: 'axfer', asset_id: TOKEN } }
  ]
)
```

### Real-Time Monitoring

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST,
  wait_for_block_when_at_tip: true,
  frequency_in_seconds: 0.5
)
```

### Historical Analysis

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST,
  max_rounds_to_sync: 1000
)

subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)
```

## Debugging

```ruby
# Enable debug logging
require 'logger'
Algokit::Subscriber.logger = Logger.new($stdout)
Algokit::Subscriber.logger.level = Logger::DEBUG

# Test single poll
result = subscriber.poll_once
puts "Rounds synced: #{result.rounds_synced}"
puts "Transactions found: #{result.subscribed_transactions.sum { |s| s.transactions.length }}"

# Check current status
status = algod.status
puts "Current round: #{status['last-round']}"
puts "Watermark: #{subscriber.watermark}"
```

## Transaction Types

| Type | Description | Common Fields |
|------|-------------|---------------|
| `pay` | ALGO payment | `amount`, `receiver`, `close-to` |
| `axfer` | Asset transfer | `asset-id`, `amount`, `receiver` |
| `acfg` | Asset config | `asset-id`, `params` (if creation) |
| `appl` | Application call | `application-id`, `application-args`, `on-completion` |
| `keyreg` | Key registration | `vote-key`, `selection-key` |
| `afrz` | Asset freeze | `asset-id`, `frozen-address`, `frozen` |

## Error Types

```ruby
Algokit::Subscriber::Error               # Base error
Algokit::Subscriber::ClientError         # API error (4xx, 5xx)
Algokit::Subscriber::TimeoutError        # Request timeout
Algokit::Subscriber::ConfigurationError  # Invalid config
```

## Useful Commands

```bash
# Run tests
bundle exec rspec

# Run specific test
bundle exec rspec spec/client/algod_client_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec

# Run linter
bundle exec rubocop

# Auto-fix lint issues
bundle exec rubocop -A

# Generate documentation
yard doc

# Build gem
gem build algokit-subscriber.gemspec

# Install local gem
gem install algokit-subscriber-0.1.0.gem
```

## Resources

- [Getting Started Guide](GETTING_STARTED.md)
- [API Reference](API_REFERENCE.md)
- [Advanced Usage](ADVANCED_USAGE.md)
- [Architecture](ARCHITECTURE.md)
- [Examples](../examples/)
- [Algorand Docs](https://developer.algorand.org/)
