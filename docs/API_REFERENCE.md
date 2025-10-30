# API Reference

Complete API documentation for AlgoKit Subscriber Ruby gem.

## Table of Contents

- [AlgorandSubscriber](#algorandsubscriber)
- [SubscriptionConfig](#subscriptionconfig)
- [Transaction Filters](#transaction-filters)
- [Balance Changes](#balance-changes)
- [ARC-28 Events](#arc-28-events)
- [Clients](#clients)
- [Models](#models)
- [Types](#types)

## AlgorandSubscriber

The main entry point for subscribing to Algorand blockchain transactions.

### Constructor

```ruby
AlgorandSubscriber.new(config, algod, indexer = nil)
```

**Parameters:**
- `config` (SubscriptionConfig) - Subscription configuration
- `algod` (AlgodClient) - Algod API client (required)
- `indexer` (IndexerClient) - Indexer API client (optional, enables faster catchup)

**Example:**
```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [{ name: 'payments', filter: { type: 'pay' } }]
)
algod = Algokit::Subscriber::Client::AlgodClient.new('https://testnet-api.algonode.cloud')
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)
```

### Instance Methods

#### `on(filter_name, &block)`

Register a handler for individual transactions matching the named filter.

**Parameters:**
- `filter_name` (String) - Name of the filter to listen to
- `block` (Block) - Handler receiving each matching transaction

**Returns:** `nil`

**Example:**
```ruby
subscriber.on('payments') do |transaction|
  puts "Payment: #{transaction['id']}"
  puts "Amount: #{transaction.dig('payment-transaction', 'amount')}"
end
```

#### `on_batch(filter_name, &block)`

Register a handler for batches of transactions matching the named filter.

**Parameters:**
- `filter_name` (String) - Name of the filter to listen to
- `block` (Block) - Handler receiving array of matching transactions

**Returns:** `nil`

**Example:**
```ruby
subscriber.on_batch('payments') do |transactions|
  total = transactions.sum { |t| t.dig('payment-transaction', 'amount') || 0 }
  puts "Batch: #{transactions.length} payments, total: #{total}"
end
```

#### `on_before_poll(&block)`

Register a handler called before each polling cycle.

**Parameters:**
- `block` (Block) - Handler receiving (watermark, current_round)

**Returns:** `nil`

**Example:**
```ruby
subscriber.on_before_poll do |watermark, current_round|
  puts "About to poll: #{watermark} -> #{current_round}"
end
```

#### `on_poll(&block)`

Register a handler called after each successful polling cycle.

**Parameters:**
- `block` (Block) - Handler receiving SubscriptionResult

**Returns:** `nil`

**Example:**
```ruby
subscriber.on_poll do |result|
  puts "Synced #{result.synced_round_range.length} rounds"
  puts "New watermark: #{result.new_watermark}"
end
```

#### `on_error(&block)`

Register an error handler for exceptions during polling.

**Parameters:**
- `block` (Block) - Handler receiving error object

**Returns:** `nil`

**Example:**
```ruby
subscriber.on_error do |error|
  puts "Error: #{error.message}"
  ErrorTracker.notify(error)
end
```

#### `poll_once`

Execute a single polling cycle.

**Returns:** `SubscriptionResult` - Result of the poll operation

**Raises:** Various exceptions on failure

**Example:**
```ruby
result = subscriber.poll_once
puts "Synced rounds: #{result.synced_round_range}"
puts "Transactions: #{result.subscribed_transactions.sum { |s| s.transactions.length }}"
```

#### `start(inspect_proc = nil, suppress_log: false)`

Start continuous polling in a loop.

**Parameters:**
- `inspect_proc` (Proc, optional) - Custom inspection proc called after each poll
- `suppress_log` (Boolean) - Suppress startup/shutdown log messages (default: false)

**Returns:** Does not return until stopped

**Raises:** `RuntimeError` if already running

**Example:**
```ruby
# Basic start
subscriber.start

# With custom inspection
subscriber.start(->(result) { puts "Custom: #{result.rounds_synced} rounds" })

# Suppressed logging
subscriber.start(suppress_log: true)
```

#### `stop(reason = nil)`

Stop the subscriber gracefully.

**Parameters:**
- `reason` (String, optional) - Reason for stopping (logged)

**Returns:** `nil`

**Example:**
```ruby
subscriber.stop('Manual shutdown')
```

#### `running?`

Check if the subscriber is currently running.

**Returns:** `Boolean`

**Example:**
```ruby
if subscriber.running?
  puts "Subscriber is active"
end
```

#### `watermark`

Get the current watermark (last synced round).

**Returns:** `Integer`

**Example:**
```ruby
puts "Current watermark: #{subscriber.watermark}"
```

---

## SubscriptionConfig

Configuration object for the subscriber.

### Constructor

```ruby
SubscriptionConfig.new(**options)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `filters` | Array | `[]` | Array of NamedTransactionFilter or filter hashes |
| `arc28_events` | Array | `[]` | Array of Arc28EventGroup definitions |
| `max_rounds_to_sync` | Integer | `100` | Max rounds to sync per algod poll |
| `max_indexer_rounds_to_sync` | Integer | `1000` | Max rounds to sync via indexer |
| `sync_behaviour` | String | `'catchup-with-indexer'` | Sync strategy (see below) |
| `frequency_in_seconds` | Float | `1.0` | Polling frequency in seconds |
| `wait_for_block_when_at_tip` | Boolean | `true` | Use low-latency mode at tip |
| `watermark_persistence` | Hash/WatermarkPersistence | `nil` | Watermark storage callbacks |

**Example:**
```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'large-payments',
      filter: {
        type: 'pay',
        min_amount: 10_000_000
      }
    }
  ],
  max_rounds_to_sync: 50,
  frequency_in_seconds: 2.0,
  watermark_persistence: {
    get: -> { File.read('watermark.txt').to_i rescue 0 },
    set: ->(w) { File.write('watermark.txt', w.to_s) }
  }
)
```

### Sync Behaviours

Available via `Algokit::Subscriber::Types::SyncBehaviour` constants:

| Constant | Value | Description |
|----------|-------|-------------|
| `CATCHUP_WITH_INDEXER` | `'catchup-with-indexer'` | Use indexer for large gaps, algod for small gaps (default) |
| `SYNC_OLDEST` | `'sync-oldest'` | Always sync from oldest unsynced round |
| `SYNC_OLDEST_START_NOW` | `'sync-oldest-start-now'` | Skip history on first run, sync from watermark after |
| `SKIP_SYNC_NEWEST` | `'skip-sync-newest'` | Jump to latest round, never sync history |
| `FAIL` | `'fail'` | Fail immediately if behind |

**Example:**
```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST
)
```

### Instance Methods

#### `validate!`

Validate the configuration.

**Returns:** `true` if valid

**Raises:** `ConfigurationError` if invalid

---

## Transaction Filters

Transaction filters determine which transactions match your subscription.

### NamedTransactionFilter

A named filter with a TransactionFilter configuration.

**Constructor:**
```ruby
NamedTransactionFilter.new(name:, filter:)
```

**Parameters:**
- `name` (String) - Unique name for this filter
- `filter` (Hash/TransactionFilter) - Filter configuration

**Example:**
```ruby
filter = Algokit::Subscriber::Types::NamedTransactionFilter.new(
  name: 'usdc-transfers',
  filter: {
    type: 'axfer',
    asset_id: 10458941,
    min_amount: 1_000_000
  }
)
```

### TransactionFilter

Filter criteria for matching transactions.

**Constructor:**
```ruby
TransactionFilter.new(**options)
```

**Available Options:**

| Option | Type | Description | Example |
|--------|------|-------------|---------|
| `type` | String | Transaction type | `'pay'`, `'axfer'`, `'appl'`, `'acfg'`, `'keyreg'`, `'afrz'` |
| `sender` | String | Sender address | `'ADDR...'` |
| `receiver` | String | Receiver address | `'ADDR...'` |
| `note_prefix` | String | Note prefix (base64) | `'myapp:'` |
| `app_id` | Integer | Application ID | `123456` |
| `asset_id` | Integer | Asset ID | `10458941` |
| `min_amount` | Integer | Minimum amount (microAlgos/base units) | `1_000_000` |
| `max_amount` | Integer | Maximum amount | `100_000_000` |
| `app_create` | Boolean | Filter app creation txns | `true` |
| `asset_create` | Boolean | Filter asset creation txns | `true` |
| `app_on_complete` | String | OnComplete action | `'NoOp'`, `'OptIn'`, etc. |
| `method_signature` | String | ARC-4 method signature | `'swap(uint64,uint64)void'` |
| `balance_changes` | Array | Balance change filters (see below) | `[{address: '...', min_amount: 1000}]` |
| `arc28_events` | Array | ARC-28 event filters (see below) | `[{group_name: 'DEX', event_name: 'Swap'}]` |
| `custom_filter` | Proc | Custom filter function | `->(txn) { txn['fee'] > 1000 }` |

**Examples:**

```ruby
# Payment filter
filter = Algokit::Subscriber::Types::TransactionFilter.new(
  type: 'pay',
  min_amount: 1_000_000,
  sender: 'SENDER_ADDRESS'
)

# Asset transfer filter
filter = Algokit::Subscriber::Types::TransactionFilter.new(
  type: 'axfer',
  asset_id: 10458941,
  receiver: 'RECEIVER_ADDRESS'
)

# Application call filter
filter = Algokit::Subscriber::Types::TransactionFilter.new(
  type: 'appl',
  app_id: 123456,
  method_signature: 'swap(uint64,uint64)void'
)

# Custom filter
filter = Algokit::Subscriber::Types::TransactionFilter.new(
  type: 'pay',
  custom_filter: ->(txn) {
    amount = txn.dig('payment-transaction', 'amount') || 0
    amount > 5_000_000 && amount < 10_000_000
  }
)
```

### Instance Methods

#### `matches?(transaction)`

Check if a transaction matches this filter.

**Parameters:**
- `transaction` (Hash) - Transaction to check

**Returns:** `Boolean`

---

## Balance Changes

Balance change tracking automatically calculates net balance changes for addresses, including inner transactions.

### BalanceChangeFilter

Filter for balance changes within transactions.

**Constructor:**
```ruby
{ address:, asset_id:, min_amount:, max_amount:, min_absolute_amount:, max_absolute_amount:, roles: }
```

**Options:**

| Option | Type | Description |
|--------|------|-------------|
| `address` | String | Address to track (required) |
| `asset_id` | Integer | Asset ID (0 for ALGO, default: 0) |
| `min_amount` | Integer | Minimum net change (can be negative) |
| `max_amount` | Integer | Maximum net change |
| `min_absolute_amount` | Integer | Minimum absolute change |
| `max_absolute_amount` | Integer | Maximum absolute change |
| `roles` | Array<String> | Roles to include (see below) |

**Roles:**
- `'Sender'` - Address sending funds
- `'Receiver'` - Address receiving funds
- `'CloseTo'` - Address receiving close-to funds
- `'AssetCreator'` - Address creating asset
- `'AssetDestroyer'` - Address destroying asset

**Example:**
```ruby
filter = Algokit::Subscriber::Types::TransactionFilter.new(
  balance_changes: [
    {
      address: 'TREASURY_ADDRESS',
      asset_id: 0, # ALGO
      min_amount: 1_000_000,
      roles: ['Receiver']
    },
    {
      address: 'TREASURY_ADDRESS',
      asset_id: 10458941, # USDC
      min_absolute_amount: 1_000_000
    }
  ]
)
```

### BalanceChange

Represents a balance change for an address.

**Attributes:**
- `address` (String) - Address
- `asset_id` (Integer) - Asset ID (0 = ALGO)
- `amount` (Integer) - Net change amount (can be negative)
- `roles` (Array<String>) - Roles in transaction

**Methods:**
- `algo_change?` - Returns true if this is an ALGO change
- `asset_change?` - Returns true if this is an asset change
- `to_h` - Convert to hash

**Example:**
```ruby
# Balance changes are added to transactions automatically
subscriber.on('payments') do |txn|
  changes = txn['balance-changes'] || []
  changes.each do |change|
    puts "#{change.address}: #{change.amount} (#{change.roles.join(', ')})"
  end
end
```

---

## ARC-28 Events

ARC-28 is the standard for Algorand smart contract events.

### Arc28EventGroup

A group of related event definitions.

**Constructor:**
```ruby
Arc28EventGroup.new(group_name:, events:)
```

**Parameters:**
- `group_name` (String) - Name for this event group
- `events` (Array<Hash/Arc28EventDefinition>) - Event definitions

**Example:**
```ruby
event_group = Algokit::Subscriber::Types::Arc28EventGroup.new(
  group_name: 'DEX',
  events: [
    {
      name: 'Swap',
      args: [
        { name: 'trader', type: 'address' },
        { name: 'amountIn', type: 'uint64' },
        { name: 'amountOut', type: 'uint64' }
      ]
    },
    {
      name: 'AddLiquidity',
      args: [
        { name: 'provider', type: 'address' },
        { name: 'amount', type: 'uint64' }
      ]
    }
  ]
)
```

### Arc28EventDefinition

Definition of a single event type.

**Constructor:**
```ruby
Arc28EventDefinition.new(name:, signature: nil, args: [])
```

**Parameters:**
- `name` (String) - Event name
- `signature` (String, optional) - Full signature (auto-generated if not provided)
- `args` (Array<Hash/Arc28EventArg>) - Event arguments

**Methods:**
- `selector` - Get the 4-byte event selector (SHA-512/256 hash)

### Arc28EventArg

Argument definition for an event.

**Constructor:**
```ruby
Arc28EventArg.new(name:, type:, struct: nil)
```

**Parameters:**
- `name` (String) - Argument name
- `type` (String) - ABI type (e.g., `'uint64'`, `'address'`, `'string'`)
- `struct` (String, optional) - Struct name for complex types

### Using ARC-28 Events

**1. Define Events:**
```ruby
events = [
  Algokit::Subscriber::Types::Arc28EventGroup.new(
    group_name: 'DEX',
    events: [
      {
        name: 'Swap',
        args: [
          { name: 'trader', type: 'address' },
          { name: 'tokenIn', type: 'uint64' },
          { name: 'amountIn', type: 'uint64' },
          { name: 'tokenOut', type: 'uint64' },
          { name: 'amountOut', type: 'uint64' }
        ]
      }
    ]
  )
]
```

**2. Configure Filter:**
```ruby
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
  arc28_events: events
)
```

**3. Handle Events:**
```ruby
subscriber.on('dex-swaps') do |txn|
  events = txn['arc28-events'] || []
  events.each do |event|
    puts "Event: #{event.event_name}"
    puts "  Trader: #{event.args['trader']}"
    puts "  Amount In: #{event.args['amountIn']}"
    puts "  Amount Out: #{event.args['amountOut']}"
  end
end
```

---

## Clients

### AlgodClient

HTTP client for the Algorand algod API.

**Constructor:**
```ruby
AlgodClient.new(server, token: nil, headers: {})
```

**Parameters:**
- `server` (String) - Algod server URL
- `token` (String, optional) - API token
- `headers` (Hash, optional) - Custom HTTP headers

**Example:**
```ruby
# Public node
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'https://testnet-api.algonode.cloud'
)

# Private node with authentication
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'http://localhost:4001',
  token: 'your-token-here'
)

# With custom headers
algod = Algokit::Subscriber::Client::AlgodClient.new(
  'https://api.example.com',
  headers: { 'X-Custom-Header' => 'value' }
)
```

**Methods:**

#### `status`
Get current node status.

**Returns:** Hash with status information

```ruby
status = algod.status
# => {
#   "last-round" => 12345,
#   "time-since-last-round" => 1234567890,
#   "catchup-time" => 0,
#   ...
# }
```

#### `block(round)`
Get a block by round number.

**Parameters:**
- `round` (Integer) - Block round number

**Returns:** Hash with block data

```ruby
block = algod.block(12345)
# => {
#   "block" => {...},
#   "cert" => {...}
# }
```

#### `status_after_block(round, timeout: 60)`
Wait for a block at or after the given round (low-latency polling).

**Parameters:**
- `round` (Integer) - Round to wait for
- `timeout` (Integer) - Timeout in seconds (default: 60)

**Returns:** Hash with status information

```ruby
status = algod.status_after_block(12345)
```

### IndexerClient

HTTP client for the Algorand indexer API.

**Constructor:**
```ruby
IndexerClient.new(server, token: nil, headers: {})
```

**Parameters:**
- `server` (String) - Indexer server URL
- `token` (String, optional) - API token
- `headers` (Hash, optional) - Custom HTTP headers

**Example:**
```ruby
indexer = Algokit::Subscriber::Client::IndexerClient.new(
  'https://testnet-idx.algonode.cloud'
)
```

**Methods:**

#### `search_transactions(**params)`
Search for transactions.

**Parameters:**
- `min_round` (Integer, optional) - Minimum round (inclusive)
- `max_round` (Integer, optional) - Maximum round (inclusive)
- `limit` (Integer, optional) - Max results per page (default: 1000)
- `next_token` (String, optional) - Pagination token
- `tx_type` (String, optional) - Transaction type
- `address` (String, optional) - Address filter
- `asset_id` (Integer, optional) - Asset ID filter
- `application_id` (Integer, optional) - Application ID filter
- Any other indexer search parameters

**Returns:** Hash with search results

```ruby
result = indexer.search_transactions(
  min_round: 1000,
  max_round: 2000,
  tx_type: 'pay',
  limit: 100
)
# => {
#   "current-round" => 2000,
#   "transactions" => [...],
#   "next-token" => "..."
# }
```

#### `health`
Get indexer health status.

**Returns:** Hash with health information

```ruby
health = indexer.health
# => {
#   "round" => 12345,
#   "is-migrating" => false,
#   ...
# }
```

---

## Models

### Status

Represents node status information.

**Constructor:**
```ruby
Status.new(data)
```

**Attributes:**
- `last_round` (Integer) - Latest round
- `time_since_last_round` (Integer) - Microseconds since last round
- `catchup_time` (Integer) - Microseconds spent catching up
- `last_version` (String) - Last consensus version

**Methods:**
- `caught_up?` - Returns true if node is caught up
- `time_since_last_round_seconds` - Time since last round in seconds

**Example:**
```ruby
status_data = algod.status
status = Algokit::Subscriber::Models::Status.new(status_data)

puts "Last round: #{status.last_round}"
puts "Caught up: #{status.caught_up?}"
```

### Block

Represents a block.

**Constructor:**
```ruby
Block.new(data)
```

**Attributes:**
- `round` (Integer) - Block round
- `timestamp` (Integer) - Block timestamp (Unix)
- `genesis_id` (String) - Genesis ID
- `genesis_hash` (String) - Genesis hash
- `transactions` (Array<Hash>) - Block transactions
- `proposer` (String, optional) - Block proposer address
- `txn_counter` (Integer) - Transaction counter

**Example:**
```ruby
block_data = algod.block(12345)
block = Algokit::Subscriber::Models::Block.new(block_data)

puts "Round: #{block.round}"
puts "Transactions: #{block.transactions.length}"
puts "Timestamp: #{Time.at(block.timestamp)}"
```

### Transaction

Represents a transaction.

**Constructor:**
```ruby
Transaction.new(data)
```

**Attributes:**
- `id` (String) - Transaction ID
- `type` (String) - Transaction type
- `sender` (String) - Sender address
- `round` (Integer) - Confirmed round
- `fee` (Integer) - Transaction fee
- `note` (String, optional) - Transaction note (base64)

**Type-specific attributes:**
- `amount` (Integer) - Payment amount (pay)
- `receiver` (String) - Payment receiver (pay)
- `close_to` (String, optional) - Close remainder to (pay)
- `asset_id` (Integer) - Asset ID (axfer/acfg)
- `asset_amount` (Integer) - Asset transfer amount (axfer)
- `application_id` (Integer) - Application ID (appl)

**Methods:**
- `payment?` - Returns true if type is 'pay'
- `asset_transfer?` - Returns true if type is 'axfer'
- `application_call?` - Returns true if type is 'appl'
- `asset_config?` - Returns true if type is 'acfg'
- `created_asset?` - Returns true if transaction created an asset
- `created_application?` - Returns true if transaction created an application

---

## Types

### SubscriptionResult

Result of a polling cycle.

**Attributes:**
- `starting_watermark` (Integer) - Watermark at start
- `new_watermark` (Integer) - Watermark after sync
- `synced_round_range` (Range/Array) - Rounds synced
- `current_round` (Integer) - Current blockchain round
- `subscribed_transactions` (Array<TransactionSubscriptionResult>) - Matching transactions

**Methods:**
- `rounds_synced` - Number of rounds synced

### TransactionSubscriptionResult

Transactions matching a specific filter.

**Attributes:**
- `filter_name` (String) - Name of the filter
- `transactions` (Array<Hash>) - Matching transactions

### BlockMetadata

Block metadata information.

**Attributes:**
- `round` (Integer) - Block round
- `timestamp` (Integer) - Block timestamp
- `genesis_id` (String) - Genesis ID
- `genesis_hash` (String) - Genesis hash

---

## Error Classes

```ruby
Algokit::Subscriber::Error               # Base error class
Algokit::Subscriber::ConfigurationError  # Invalid configuration
Algokit::Subscriber::ClientError         # API client error
Algokit::Subscriber::TimeoutError        # Request timeout
```

---

## Utilities

### Logger

Configure the gem's logger:

```ruby
# Use custom logger
Algokit::Subscriber.logger = Logger.new($stdout)

# Set log level
Algokit::Subscriber.logger.level = Logger::DEBUG

# Disable logging
Algokit::Subscriber.logger = Logger.new(IO::NULL)
```

### Utils

```ruby
# Encode/decode base64
Algokit::Subscriber::Utils.base64_encode(string)
Algokit::Subscriber::Utils.base64_decode(base64_string)

# Encode address
Algokit::Subscriber::Utils.encode_address(bytes)
```
