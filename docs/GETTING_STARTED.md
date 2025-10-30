# Getting Started with AlgoKit Subscriber

A comprehensive guide to get you up and running with the AlgoKit Subscriber Ruby gem.

## Table of Contents

- [Installation](#installation)
- [Basic Concepts](#basic-concepts)
- [Your First Subscriber](#your-first-subscriber)
- [Common Patterns](#common-patterns)
- [Testing Your Subscriber](#testing-your-subscriber)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## Installation

### Requirements

- Ruby 3.1 or higher
- Access to an Algorand algod node (public or private)
- Optional: Access to an Algorand indexer node for faster historical catchup

### Install the Gem

Add to your Gemfile:

```ruby
gem 'algokit-subscriber'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install algokit-subscriber
```

### Verify Installation

Create a test file to verify the installation:

```ruby
# test_install.rb
require 'algokit/subscriber'

puts "AlgoKit Subscriber version: #{Algokit::Subscriber::VERSION}"
puts "Installation successful! ✓"
```

Run it:

```bash
ruby test_install.rb
```

## Basic Concepts

### What is AlgoKit Subscriber?

AlgoKit Subscriber is a library for subscribing to Algorand blockchain transactions in real-time. Instead of manually polling the blockchain and filtering transactions, you define filters and the library handles the rest.

### Key Components

1. **AlgodClient** - Connects to an Algorand node
2. **IndexerClient** - (Optional) Connects to an indexer for faster catchup
3. **SubscriptionConfig** - Defines what transactions you want to monitor
4. **AlgorandSubscriber** - Main class that orchestrates everything
5. **Filters** - Define matching criteria for transactions
6. **Event Handlers** - Your code that runs when matching transactions are found

### How It Works

```
┌─────────────┐
│  Algorand   │
│  Blockchain │
└──────┬──────┘
       │
       │ (polls every N seconds)
       ↓
┌─────────────────┐
│ AlgoKit         │
│ Subscriber      │
└──────┬──────────┘
       │
       │ (filters transactions)
       ↓
┌─────────────────┐
│ Your Event      │
│ Handlers        │
└─────────────────┘
```

## Your First Subscriber

Let's build a simple payment tracker step by step.

### Step 1: Set Up Clients

First, create connections to Algorand nodes:

```ruby
require 'algokit/subscriber'

# Connect to TestNet (public nodes, no authentication needed)
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'https://testnet-api.algonode.cloud'
)

# Optional: Add indexer for faster historical catchup
indexer = Algokit::Subscriber::Client::IndexerClient.new(
  'https://testnet-idx.algonode.cloud'
)
```

**For MainNet:**
```ruby
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'https://mainnet-api.algonode.cloud'
)
```

**For a private node:**
```ruby
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'http://localhost:4001',
  token: 'your-token-here'
)
```

### Step 2: Create a Configuration

Define what transactions you want to monitor:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'payments',  # Give your filter a name
      filter: {
        type: 'pay',     # Transaction type (payment)
        min_amount: 1_000_000  # At least 1 ALGO (in microAlgos)
      }
    }
  ],
  frequency_in_seconds: 1.0  # Poll every second
)
```

### Step 3: Create the Subscriber

```ruby
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(
  config,
  algod,
  indexer  # Optional
)
```

### Step 4: Add Event Handlers

Define what happens when a matching transaction is found:

```ruby
subscriber.on('payments') do |transaction|
  amount = transaction.dig('payment-transaction', 'amount')
  sender = transaction['sender']
  receiver = transaction.dig('payment-transaction', 'receiver')
  
  puts "💰 Payment detected!"
  puts "  Amount: #{amount / 1_000_000.0} ALGO"
  puts "  From: #{sender}"
  puts "  To: #{receiver}"
  puts "  ID: #{transaction['id']}"
  puts
end
```

### Step 5: Start Monitoring

```ruby
puts "Starting payment tracker..."
puts "Press Ctrl+C to stop"
puts

# Handle graceful shutdown
Signal.trap('INT') do
  puts "\nStopping subscriber..."
  subscriber.stop('User interrupted')
  exit 0
end

# Start monitoring
subscriber.start
```

### Complete Example

Save this as `payment_tracker.rb`:

```ruby
#!/usr/bin/env ruby
require 'algokit/subscriber'

# 1. Create clients
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'https://testnet-api.algonode.cloud'
)

# 2. Configure what to track
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'payments',
      filter: {
        type: 'pay',
        min_amount: 1_000_000  # 1+ ALGO
      }
    }
  ],
  frequency_in_seconds: 1.0
)

# 3. Create subscriber
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

# 4. Add event handler
subscriber.on('payments') do |txn|
  amount = txn.dig('payment-transaction', 'amount')
  puts "💰 #{amount / 1_000_000.0} ALGO - #{txn['id']}"
end

# 5. Handle shutdown
Signal.trap('INT') do
  puts "\nStopping..."
  subscriber.stop
  exit 0
end

# 6. Start
puts "Tracking payments on TestNet..."
subscriber.start
```

Run it:

```bash
ruby payment_tracker.rb
```

You should see output like:
```
Tracking payments on TestNet...
💰 5.0 ALGO - ABC123...
💰 2.5 ALGO - DEF456...
```

## Common Patterns

### Pattern 1: Track Asset Transfers

Monitor USDC transfers on TestNet:

```ruby
USDC_ASSET_ID = 10_458_941  # TestNet USDC

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'usdc-transfers',
      filter: {
        type: 'axfer',           # Asset transfer
        asset_id: USDC_ASSET_ID
      }
    }
  ]
)

subscriber.on('usdc-transfers') do |txn|
  amount = txn.dig('asset-transfer-transaction', 'amount')
  puts "USDC Transfer: #{amount / 1_000_000.0} USDC"
end
```

### Pattern 2: Monitor Specific Address

Track all transactions to/from a treasury address:

```ruby
TREASURY = 'YOUR_ADDRESS_HERE'

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'treasury-incoming',
      filter: {
        type: 'pay',
        receiver: TREASURY
      }
    },
    {
      name: 'treasury-outgoing',
      filter: {
        type: 'pay',
        sender: TREASURY
      }
    }
  ]
)

subscriber.on('treasury-incoming') do |txn|
  puts "📥 Received: #{txn.dig('payment-transaction', 'amount')} microAlgos"
end

subscriber.on('treasury-outgoing') do |txn|
  puts "📤 Sent: #{txn.dig('payment-transaction', 'amount')} microAlgos"
end
```

### Pattern 3: Batch Processing

Process multiple transactions at once:

```ruby
subscriber.on_batch('payments') do |transactions|
  total = transactions.sum { |t| t.dig('payment-transaction', 'amount') || 0 }
  
  puts "Batch of #{transactions.length} payments"
  puts "Total value: #{total / 1_000_000.0} ALGO"
end
```

### Pattern 4: Track Balance Changes

Automatically track net balance changes for an address:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'treasury-changes',
      filter: {
        balance_changes: [
          {
            address: TREASURY,
            min_absolute_amount: 1_000_000  # Any change >= 1 ALGO
          }
        ]
      }
    }
  ]
)

subscriber.on('treasury-changes') do |txn|
  changes = txn['balance-changes'] || []
  treasury_change = changes.find { |c| c.address == TREASURY }
  
  if treasury_change
    change = treasury_change.amount / 1_000_000.0
    direction = change > 0 ? "received" : "sent"
    puts "Treasury #{direction} #{change.abs} ALGO"
  end
end
```

### Pattern 5: Application Monitoring

Monitor smart contract calls:

```ruby
APP_ID = 123456

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'app-calls',
      filter: {
        type: 'appl',
        app_id: APP_ID
      }
    }
  ]
)

subscriber.on('app-calls') do |txn|
  puts "App call to #{APP_ID}"
  
  # Check for inner transactions
  inner_txns = txn['inner-txns'] || []
  puts "  Generated #{inner_txns.length} inner transactions"
end
```

## Testing Your Subscriber

### Use TestNet for Development

Always start with TestNet for development and testing:

```ruby
# TestNet nodes (recommended for testing)
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'https://testnet-api.algonode.cloud'
)

indexer = Algokit::Subscriber::Client::IndexerClient.new(
  'https://testnet-idx.algonode.cloud'
)
```

### Single Poll for Testing

Test your configuration with a single poll:

```ruby
result = subscriber.poll_once

puts "Synced #{result.rounds_synced} rounds"
puts "Found #{result.subscribed_transactions.sum { |s| s.transactions.length }} transactions"

result.subscribed_transactions.each do |sub|
  puts "Filter '#{sub.filter_name}': #{sub.transactions.length} matches"
end
```

### Start from Current Round

Skip historical data when testing:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST
)
```

### Add Logging

Enable debug logging:

```ruby
require 'logger'

Algokit::Subscriber.logger = Logger.new($stdout)
Algokit::Subscriber.logger.level = Logger::DEBUG
```

### Test with Known Transactions

Use the indexer to find test transactions:

```ruby
# Find recent payments
result = indexer.search_transactions(
  min_round: 1_000_000,
  max_round: 1_001_000,
  tx_type: 'pay',
  limit: 10
)

puts "Found #{result['transactions'].length} test transactions"
```

## Troubleshooting

### Issue: No Transactions Appearing

**Check 1: Verify your filter**
```ruby
# Add a very broad filter to test
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    { name: 'all', filter: {} }  # Match everything
  ]
)
```

**Check 2: Verify node connectivity**
```ruby
status = algod.status
puts "Connected! Last round: #{status['last-round']}"
```

**Check 3: Check watermark**
```ruby
puts "Current watermark: #{subscriber.watermark}"
# If watermark is at tip, no historical transactions will be processed
```

### Issue: Subscriber Too Slow

**Solution 1: Use indexer for catchup**
```ruby
# Add indexer client for faster historical sync
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(
  config, algod, indexer
)
```

**Solution 2: Reduce rounds per sync**
```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  max_rounds_to_sync: 30  # Smaller batches
)
```

**Solution 3: Skip history**
```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST
)
```

### Issue: Missing Transactions After Restart

**Solution: Add watermark persistence**
```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  watermark_persistence: {
    get: -> { File.read('watermark.txt').to_i rescue 0 },
    set: ->(w) { File.write('watermark.txt', w.to_s) }
  }
)
```

### Issue: High CPU Usage

**Solution 1: Reduce polling frequency**
```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  frequency_in_seconds: 5.0  # Poll every 5 seconds instead of 1
)
```

**Solution 2: Disable wait-for-block**
```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  wait_for_block_when_at_tip: false
)
```

### Issue: Authentication Errors

For private nodes, ensure you're passing the token:

```ruby
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'http://localhost:4001',
  token: ENV['ALGOD_TOKEN']  # Read from environment
)
```

## Next Steps

Now that you have the basics working:

1. **Learn Advanced Filtering** - Read the [Advanced Usage Guide](ADVANCED_USAGE.md)
2. **Explore Examples** - Check out the [examples directory](../examples/)
3. **API Reference** - See the complete [API Reference](API_REFERENCE.md)
4. **Production Deployment** - Read about [Production Best Practices](ADVANCED_USAGE.md#production-deployment)

### Recommended Learning Path

1. ✓ Complete this Getting Started guide
2. Study the example files in `examples/`
3. Read about [Sync Behaviors](../examples/SYNC_BEHAVIORS.md)
4. Implement your use case
5. Read [Advanced Usage Guide](ADVANCED_USAGE.md) for optimization
6. Review [API Reference](API_REFERENCE.md) for complete details

## Quick Reference

### Common Transaction Types

| Type | Description | Example Use Case |
|------|-------------|------------------|
| `pay` | ALGO payment | Payment tracking |
| `axfer` | Asset transfer | Token transfers |
| `acfg` | Asset config | Asset creation/modification |
| `appl` | Application call | Smart contract monitoring |
| `keyreg` | Key registration | Validator tracking |
| `afrz` | Asset freeze | Asset freeze/unfreeze |

### Environment Variables

```bash
# Optional environment variables
export ALGOD_SERVER="https://testnet-api.algonode.cloud"
export ALGOD_TOKEN=""
export INDEXER_SERVER="https://testnet-idx.algonode.cloud"
export INDEXER_TOKEN=""
```

Then in your code:
```ruby
algod = Algokit::Subscriber::Client::AlgodClient.new(
  ENV['ALGOD_SERVER'],
  token: ENV['ALGOD_TOKEN']
)
```

### Useful Links

- [Algorand Developer Portal](https://developer.algorand.org/)
- [Algod API Reference](https://developer.algorand.org/docs/rest-apis/algod/)
- [Indexer API Reference](https://developer.algorand.org/docs/rest-apis/indexer/)
- [AlgoExplorer TestNet](https://testnet.algoexplorer.io/)
- [Public Algorand Nodes](https://algonode.io/)

## Getting Help

If you're stuck:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review the [examples directory](../examples/)
3. Search existing [GitHub issues](https://github.com/loedn/algokit-subscriber-rb/issues)
4. Open a new issue with:
   - Ruby version
   - Gem version
   - Minimal code to reproduce
   - Error messages

Happy building! 🚀
