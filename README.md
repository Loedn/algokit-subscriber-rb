# AlgoKit Subscriber (Ruby)

[![Tests](https://img.shields.io/badge/tests-189%20passing-success)](https://github.com/algorandfoundation/algokit-subscriber-rb)
[![Coverage](https://img.shields.io/badge/coverage-82%25-green)](https://github.com/algorandfoundation/algokit-subscriber-rb)
[![Ruby](https://img.shields.io/badge/ruby-3.1%2B-red)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE.txt)

A Ruby library for subscribing to Algorand blockchain transactions with comprehensive filtering, balance change tracking, and ARC-28 event support.

This gem is a Ruby port of [AlgoKit Subscriber TS](https://github.com/algorandfoundation/algokit-subscriber-ts).

## 📚 Documentation

- **[Getting Started Guide](docs/GETTING_STARTED.md)** - New to AlgoKit Subscriber? Start here!
- **[API Reference](docs/API_REFERENCE.md)** - Complete API documentation
- **[Advanced Usage Guide](docs/ADVANCED_USAGE.md)** - Advanced patterns, optimization, and production deployment
- **[Architecture & Internals](docs/ARCHITECTURE.md)** - Deep dive into how the gem works
- **[Examples](examples/)** - Working examples for different use cases

**Quick Links:** [Installation](#installation) · [Quick Start](#quick-start) · [Examples](#examples) · [Features](#features) · [Contributing](#contributing)

## Features

- 🔍 **Comprehensive Filtering** - Filter by transaction type, sender, receiver, amounts, applications, assets, and more
- 💰 **Balance Change Tracking** - Automatically track balance changes including inner transactions
- 📡 **ARC-28 Event Support** - Parse and filter standardized event logs from smart contracts
- ⚡ **Multiple Sync Strategies** - Catchup with indexer or real-time with algod
- 🔄 **Automatic Recovery** - Watermark-based crash recovery
- 🎯 **Low Latency** - Sub-second transaction notification with wait-for-block mode
- 🧵 **Thread-Safe** - Built with concurrent-ruby for production use
- 📊 **Event-Driven** - Node.js-style event emitter pattern

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'algokit-subscriber'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install algokit-subscriber
```

## Quick Start

```ruby
require 'algokit/subscriber'

# Create clients
algod = Algokit::Subscriber::Client::AlgodClient.new('https://testnet-api.algonode.cloud')
indexer = Algokit::Subscriber::Client::IndexerClient.new('https://testnet-idx.algonode.cloud')

# Configure what to subscribe to
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'payments',
      filter: { type: 'pay', min_amount: 1_000_000 } # Payments > 1 ALGO
    }
  ],
  frequency_in_seconds: 1.0
)

# Create subscriber
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

# Handle events
subscriber.on('payments') do |transaction|
  puts "Payment: #{transaction['id']}"
  puts "  Amount: #{transaction.dig('payment-transaction', 'amount')} microAlgos"
end

# Start monitoring
subscriber.start
```

## Usage Examples

### Basic Payment Monitoring

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'large-payments',
      filter: {
        type: 'pay',
        min_amount: 10_000_000 # 10 ALGO
      }
    }
  ]
)

subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

subscriber.on('large-payments') do |txn|
  amount = txn.dig('payment-transaction', 'amount')
  puts "Large payment: #{amount / 1_000_000.0} ALGO"
end

subscriber.start
```

### Asset Transfer Monitoring

```ruby
USDC_ASSET_ID = 10_458_941 # TestNet USDC

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'usdc-transfers',
      filter: {
        type: 'axfer',
        asset_id: USDC_ASSET_ID
      }
    }
  ]
)

subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

subscriber.on('usdc-transfers') do |txn|
  amount = txn.dig('asset-transfer-transaction', 'amount')
  puts "USDC Transfer: #{amount / 1_000_000.0} USDC"
end

subscriber.start
```

### Application Call Monitoring

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'app-calls',
      filter: {
        type: 'appl',
        app_id: 123456
      }
    }
  ]
)

subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

subscriber.on('app-calls') do |txn|
  puts "App call to #{txn.dig('application-transaction', 'application-id')}"
end

subscriber.start
```

### Balance Change Tracking

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'treasury-deposits',
      filter: {
        type: 'pay',
        balance_changes: [
          {
            address: 'TREASURY_ADDRESS_HERE',
            min_amount: 1_000_000,
            roles: ['Receiver']
          }
        ]
      }
    }
  ]
)

subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

subscriber.on('treasury-deposits') do |txn|
  changes = txn['balance-changes'] || []
  treasury_change = changes.find { |c| c.address == 'TREASURY_ADDRESS_HERE' }
  puts "Treasury received: #{treasury_change.amount} microAlgos"
end

subscriber.start
```

### ARC-28 Event Listening

```ruby
arc28_events = [
  Algokit::Subscriber::Types::Arc28EventGroup.new(
    group_name: 'DEX',
    events: [
      {
        name: 'Swap',
        args: [
          { name: 'trader', type: 'address' },
          { name: 'amountIn', type: 'uint64' },
          { name: 'amountOut', type: 'uint64' }
        ]
      }
    ]
  )
]

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'dex-swaps',
      filter: {
        type: 'appl',
        app_id: 789,
        arc28_events: [
          { group_name: 'DEX', event_name: 'Swap' }
        ]
      }
    }
  ],
  arc28_events: arc28_events
)

subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

subscriber.on('dex-swaps') do |txn|
  events = txn['arc28-events'] || []
  events.each do |event|
    puts "Swap: #{event.args['amountIn']} -> #{event.args['amountOut']}"
  end
end

subscriber.start
```

### Batch Processing

```ruby
subscriber.on_batch('payments') do |transactions|
  total = transactions.sum { |txn| txn.dig('payment-transaction', 'amount') || 0 }
  puts "Batch of #{transactions.length} payments, total: #{total} microAlgos"
end
```

### Watermark Persistence

```ruby
# File-based persistence
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  watermark_persistence: {
    get: -> { File.read('watermark.txt').to_i rescue 0 },
    set: ->(w) { File.write('watermark.txt', w.to_s) }
  }
)

# Database persistence
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  watermark_persistence: {
    get: -> { Watermark.last&.round || 0 },
    set: ->(w) { Watermark.create!(round: w) }
  }
)
```

### Lifecycle Events

```ruby
subscriber.on_before_poll do |watermark, current_round|
  puts "About to poll: #{watermark} -> #{current_round}"
end

subscriber.on_poll do |result|
  puts "Synced #{result.synced_round_range.length} rounds"
end

subscriber.on_error do |error|
  puts "Error: #{error.message}"
  # Send to error tracking service
end
```

## Configuration Options

For detailed configuration options, see the [API Reference - SubscriptionConfig](docs/API_REFERENCE.md#subscriptionconfig).

### Quick Reference

**Sync Behaviors:**
- `catchup-with-indexer` - Use indexer for large gaps, algod for small gaps (default)
- `sync-oldest` - Always sync from oldest unsynced round
- `sync-oldest-start-now` - Skip history, start from current round
- `skip-sync-newest` - Jump to latest round immediately
- `fail` - Fail if behind

**Transaction Filter Options:**
`type`, `sender`, `receiver`, `note_prefix`, `app_id`, `asset_id`, `min_amount`, `max_amount`, `app_create`, `asset_create`, `app_on_complete`, `method_signature`, `balance_changes`, `arc28_events`, `custom_filter`

See [API Reference - Transaction Filters](docs/API_REFERENCE.md#transaction-filters) for complete details.

## Examples

See the [examples](examples/) directory for complete working examples:

- [data_history_museum.rb](examples/data_history_museum.rb) - Monitor DHM asset operations
- [usdc_monitoring.rb](examples/usdc_monitoring.rb) - Track USDC transfers
- [simple_payment_tracker.rb](examples/simple_payment_tracker.rb) - Basic payment monitoring
- [arc28_event_listener.rb](examples/arc28_event_listener.rb) - Listen for smart contract events

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests.

```bash
# Install dependencies
bundle install

# Run all tests (255 tests, 83% coverage)
bundle exec rspec

# Run tests with coverage report
COVERAGE=true bundle exec rspec

# Run documentation examples tests (66 tests)
bundle exec rspec spec/documentation_examples_spec.rb

# Run specific test file
bundle exec rspec spec/client/algod_client_spec.rb

# Run linter
bundle exec rubocop
```

### Test Suite

- **255 tests total** including **66 documentation example tests**
- **83% code coverage**
- All code examples from documentation are tested
- See [docs/TESTING.md](docs/TESTING.md) for detailed testing guide

## Architecture

The library is organized into several layers:

1. **Clients** (`lib/algokit/subscriber/client/`) - HTTP clients for algod and indexer
2. **Models** (`lib/algokit/subscriber/models/`) - Data models for blocks, transactions, status
3. **Types** (`lib/algokit/subscriber/types/`) - Type definitions for filters, events, config
4. **Transform** (`lib/algokit/subscriber/transform.rb`) - Format conversion and data extraction
5. **Subscriptions** (`lib/algokit/subscriber/subscriptions.rb`) - Core subscription logic
6. **AlgorandSubscriber** (`lib/algokit/subscriber/algorand_subscriber.rb`) - Main public API

## Performance

- **Algod sync**: Fetches 30 blocks in parallel (~1-2s for 30 blocks)
- **Indexer sync**: Up to 1000 transactions per request with pagination
- **Pre-filters**: Reduce data transfer by 50-90%
- **Memory**: Processes in chunks, no accumulation
- **Coverage**: 82% test coverage with 189 passing tests

## Documentation

### Full Documentation

For comprehensive documentation, visit the [docs directory](docs/):

- **[Getting Started Guide](docs/GETTING_STARTED.md)** - Installation, basic concepts, your first subscriber, and common patterns
- **[API Reference](docs/API_REFERENCE.md)** - Complete API documentation for all classes and methods
- **[Advanced Usage Guide](docs/ADVANCED_USAGE.md)** - Advanced filtering, balance tracking, ARC-28 events, sync strategies, performance optimization, error handling, production deployment, and monitoring
- **[Architecture & Internals](docs/ARCHITECTURE.md)** - Deep dive into the gem's architecture, data flow, threading model, and design decisions

### Learning Path

1. **New users:** Start with [Getting Started Guide](docs/GETTING_STARTED.md)
2. **Building features:** Check [API Reference](docs/API_REFERENCE.md) and [Examples](examples/)
3. **Production deployment:** Read [Advanced Usage - Production Deployment](docs/ADVANCED_USAGE.md#production-deployment)
4. **Understanding internals:** Explore [Architecture & Internals](docs/ARCHITECTURE.md)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/loedn/algokit-subscriber-rb.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure:
- All tests pass (`bundle exec rspec`)
- Code follows style guide (`bundle exec rubocop`)
- New features have tests
- Documentation is updated (both inline and in `docs/`)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

This library is a Ruby port of [algokit-subscriber-ts](https://github.com/algorandfoundation/algokit-subscriber-ts) by the Algorand Foundation.

## Resources

- [Algorand Developer Portal](https://dev.algorand.co/)
- [Algod REST API](https://dev.algorand.co/reference/rest-api/algod/)
- [Indexer REST API](https://dev.algorand.co/reference/rest-api/indexer/)
- [ARC-28 Events Standard](https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0028.md)
