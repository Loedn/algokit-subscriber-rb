# AlgoKit Subscriber (Ruby)

[![Tests](https://img.shields.io/badge/tests-189%20passing-success)](https://github.com/algorandfoundation/algokit-subscriber-rb)
[![Coverage](https://img.shields.io/badge/coverage-82%25-green)](https://github.com/algorandfoundation/algokit-subscriber-rb)
[![Ruby](https://img.shields.io/badge/ruby-3.1%2B-red)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE.txt)

A Ruby library for subscribing to Algorand blockchain transactions with comprehensive filtering, balance change tracking, and ARC-28 event support.
This repo is a port of [Algokit Subscriber TS](https://github.com/algorandfoundation/algokit-subscriber-ts)

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

### SubscriptionConfig

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `filters` | Array | `[]` | Transaction filters to subscribe to |
| `arc28_events` | Array | `[]` | ARC-28 event definitions |
| `max_rounds_to_sync` | Integer | `100` | Max rounds to sync per algod poll |
| `max_indexer_rounds_to_sync` | Integer | `1000` | Max rounds to sync via indexer |
| `sync_behaviour` | String | `'catchup-with-indexer'` | Sync strategy |
| `frequency_in_seconds` | Float | `1.0` | Polling frequency |
| `wait_for_block_when_at_tip` | Boolean | `true` | Use low-latency mode at tip |
| `watermark_persistence` | Hash | `nil` | Watermark storage callbacks |

### Sync Behaviors

- `catchup-with-indexer` - Use indexer for large gaps, algod for small gaps
- `sync-oldest` - Always sync from oldest unsynced round
- `sync-oldest-start-now` - Skip history, start from current round
- `skip-sync-newest` - Jump to latest round immediately
- `fail` - Fail if behind

### Transaction Filter Options

| Filter | Type | Description |
|--------|------|-------------|
| `type` | String | Transaction type (`pay`, `axfer`, `acfg`, `appl`, `keyreg`, `afrz`) |
| `sender` | String | Sender address |
| `receiver` | String | Receiver address |
| `note_prefix` | String | Note prefix (base64) |
| `app_id` | Integer | Application ID |
| `asset_id` | Integer | Asset ID |
| `min_amount` | Integer | Minimum amount (microAlgos/base units) |
| `max_amount` | Integer | Maximum amount |
| `app_create` | Boolean | Application creation |
| `asset_create` | Boolean | Asset creation |
| `app_on_complete` | String | OnComplete action |
| `method_signature` | String | ARC-4 method signature |
| `balance_changes` | Array | Balance change filters |
| `arc28_events` | Array | ARC-28 event filters |
| `custom_filter` | Proc | Custom filter function |

## API Reference

### AlgorandSubscriber

#### `new(config, algod, indexer = nil)`
Creates a new subscriber instance.

#### `on(filter_name, &block)`
Register a handler for individual transactions matching the filter.

#### `on_batch(filter_name, &block)`
Register a handler for batches of transactions matching the filter.

#### `on_before_poll(&block)`
Register a handler called before each poll (receives watermark and current_round).

#### `on_poll(&block)`
Register a handler called after each poll (receives SubscriptionResult).

#### `on_error(&block)`
Register an error handler (receives error object).

#### `poll_once`
Execute a single poll cycle. Returns SubscriptionResult.

#### `start(inspect_proc = nil, suppress_log: false)`
Start continuous polling. Optionally pass an inspect proc for custom logging.

#### `stop(reason = nil)`
Stop the subscriber gracefully.

#### `running?`
Check if the subscriber is currently running.

### Clients

#### AlgodClient

```ruby
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'https://testnet-api.algonode.cloud',
  token: 'your-token',
  headers: { 'X-Custom-Header' => 'value' }
)

status = algod.status
block = algod.block(round)
algod.status_after_block(round) # Low-latency wait
```

#### IndexerClient

```ruby
indexer = Algokit::Subscriber::Client::IndexerClient.new(
  'https://testnet-idx.algonode.cloud',
  token: 'your-token'
)

result = indexer.search_transactions(
  min_round: 1000,
  max_round: 2000,
  tx_type: 'pay',
  address: 'ADDRESS_HERE'
)

health = indexer.health
```

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

# Run tests
bundle exec rspec

# Run tests with coverage
COVERAGE=true bundle exec rspec

# Run specific test
bundle exec rspec spec/client/algod_client_spec.rb

# Run linter
bundle exec rubocop
```

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
- Documentation is updated

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

This library is a Ruby port of [algokit-subscriber-ts](https://github.com/algorandfoundation/algokit-subscriber-ts) by the Algorand Foundation.

## Resources

- [Algorand Developer Portal](https://dev.algorand.co/)
- [Algod REST API](https://dev.algorand.co/reference/rest-api/algod/)
- [Indexer REST API](https://dev.algorand.co/reference/rest-api/indexer/)
- [ARC-28 Events Standard](https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0028.md)
