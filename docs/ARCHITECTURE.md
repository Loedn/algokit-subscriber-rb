# Architecture & Internals

Deep dive into the internal architecture and design decisions of AlgoKit Subscriber.

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Core Components](#core-components)
- [Data Flow](#data-flow)
- [Threading Model](#threading-model)
- [Transaction Processing Pipeline](#transaction-processing-pipeline)
- [Sync Strategies Internals](#sync-strategies-internals)
- [Balance Change Algorithm](#balance-change-algorithm)
- [ARC-28 Event Parsing](#arc-28-event-parsing)
- [Performance Characteristics](#performance-characteristics)
- [Design Decisions](#design-decisions)

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      AlgorandSubscriber                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   Event Emitter                        │ │
│  │  (AsyncEventEmitter - Thread-safe event handling)     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                 Subscription Config                    │ │
│  │  - Filters                                             │ │
│  │  - Sync Behavior                                       │ │
│  │  - Watermark Persistence                               │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─────────────────┐              ┌──────────────────────┐  │
│  │  Poll Loop      │              │   Subscriptions      │  │
│  │  - Frequency    │──────────────│   - get_subscribed   │  │
│  │  - Wait Block   │              │   - Filter/Match     │  │
│  └─────────────────┘              └──────────────────────┘  │
└───────────────────────────┬──────────────┬───────────────────┘
                            │              │
          ┌─────────────────┘              └──────────────────┐
          │                                                    │
┌─────────▼─────────┐                            ┌────────────▼────────┐
│   AlgodClient     │                            │   IndexerClient     │
│  - status()       │                            │  - search_txns()    │
│  - block()        │                            │  - health()         │
│  - status_after() │                            └─────────────────────┘
└───────────────────┘                                      │
          │                                                │
          │                                                │
┌─────────▼────────────────────────────────────────────────▼───────────┐
│                        Algorand Network                               │
│                    (algod nodes / indexer)                            │
└───────────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. AlgorandSubscriber

**File:** `lib/algokit/subscriber/algorand_subscriber.rb`

Main orchestrator class that:
- Manages the polling loop
- Coordinates with clients
- Emits events to registered handlers
- Handles watermark state
- Manages start/stop lifecycle

**Key Methods:**
- `poll_once` - Execute single poll cycle
- `start` - Begin continuous polling
- `stop` - Graceful shutdown
- `on(filter_name)` - Register event handler
- `on_batch(filter_name)` - Register batch handler

**State Management:**
- `@running` - Boolean flag for active state
- `@stop_signal` - Concurrent::Event for shutdown coordination
- `@watermark` - Current position in blockchain
- `@mutex` - Thread synchronization

### 2. Subscriptions

**File:** `lib/algokit/subscriber/subscriptions.rb`

Core subscription logic that:
- Determines sync strategy
- Fetches transactions from algod/indexer
- Applies filters
- Calculates balance changes
- Parses ARC-28 events

**Key Methods:**
- `get_subscribed_transactions` - Main entry point
- `get_algod_subscribed_transactions` - Algod sync path
- `get_indexer_subscribed_transactions` - Indexer sync path
- `filter_transactions` - Apply filters to transactions

**Strategy Selection:**
```ruby
def self.get_subscribed_transactions(config:, watermark:, current_round:, algod:, indexer:)
  case config.sync_behaviour
  when SyncBehaviour::CATCHUP_WITH_INDEXER
    # Use indexer for large gaps, algod for small
  when SyncBehaviour::SYNC_OLDEST
    # Always use oldest unsynced
  when SyncBehaviour::SKIP_SYNC_NEWEST
    # Jump to newest
  # ...
  end
end
```

### 3. Transform

**File:** `lib/algokit/subscriber/transform.rb`

Data transformation layer that:
- Converts algod block format to indexer transaction format
- Extracts balance changes from transactions
- Parses ARC-28 events from logs
- Normalizes transaction data

**Key Methods:**
- `block_to_transactions` - Convert block to transactions
- `extract_balance_changes` - Calculate balance changes
- `extract_arc28_events` - Parse event logs

### 4. Clients

#### AlgodClient

**File:** `lib/algokit/subscriber/client/algod_client.rb`

HTTP client for algod API:
- Uses Faraday for HTTP requests
- Automatic retry with exponential backoff
- Connection pooling
- Custom headers support

**Key Features:**
- Parallel block fetching (up to 30 blocks concurrently)
- Wait-for-block optimization
- Error handling and retries

#### IndexerClient

**File:** `lib/algokit/subscriber/client/indexer_client.rb`

HTTP client for indexer API:
- Transaction search with pagination
- Filter pre-application (reduce network traffic)
- Automatic pagination handling

### 5. Event Emitter

**File:** `lib/algokit/subscriber/async_event_emitter.rb`

Thread-safe event emission:
- Based on Node.js EventEmitter pattern
- Supports async event handling
- Multiple listeners per event
- Error isolation (one handler failure doesn't affect others)

```ruby
class AsyncEventEmitter
  def on(event_name, &block)
    @listeners[event_name] ||= []
    @listeners[event_name] << block
  end
  
  def emit(event_name, *args)
    return unless @listeners[event_name]
    
    @listeners[event_name].each do |listener|
      Thread.new { listener.call(*args) }
    rescue => e
      # Isolate errors
    end
  end
end
```

## Data Flow

### Polling Cycle

```
1. poll_once
   │
   ├─→ Get current round from algod
   │
   ├─→ Emit 'before_poll' event
   │
   ├─→ Subscriptions.get_subscribed_transactions
   │   │
   │   ├─→ Determine sync strategy
   │   │
   │   ├─→ Fetch transactions (algod or indexer)
   │   │
   │   ├─→ Transform to standard format
   │   │   ├─→ Extract balance changes
   │   │   └─→ Parse ARC-28 events
   │   │
   │   ├─→ Apply filters
   │   │
   │   └─→ Return SubscriptionResult
   │
   ├─→ Emit individual transaction events
   │
   ├─→ Emit batch events
   │
   ├─→ Update watermark
   │
   ├─→ Persist watermark
   │
   └─→ Emit 'poll' event
```

### Transaction Filtering

```
Transaction
   │
   ├─→ Type filter (pay, axfer, appl, etc.)
   │
   ├─→ Address filters (sender, receiver)
   │
   ├─→ Amount filters (min/max)
   │
   ├─→ App/Asset ID filters
   │
   ├─→ Balance change filters
   │   ├─→ Calculate net changes
   │   ├─→ Apply role filters
   │   └─→ Apply amount filters
   │
   ├─→ ARC-28 event filters
   │   ├─→ Parse logs
   │   ├─→ Match event signatures
   │   └─→ Decode arguments
   │
   └─→ Custom filter function
```

## Threading Model

### Main Thread

Runs the polling loop:
```ruby
def poll_loop
  loop do
    break if @stop_signal.set?
    
    result = poll_once
    
    sleep(frequency) unless at_tip
  end
end
```

### Event Handler Threads

Each event emission spawns new threads:
```ruby
# Per-transaction events
transactions.each do |txn|
  Thread.new { handler.call(txn) }
end

# Batch events
Thread.new { batch_handler.call(transactions) }
```

### Thread Safety

- `@mutex` protects running state
- `Concurrent::Event` for shutdown signaling
- Thread-local storage for isolated processing
- No shared mutable state between handlers

## Transaction Processing Pipeline

### Stage 1: Fetching

#### Algod Path
```ruby
# Parallel block fetching (optimal performance)
blocks = Concurrent::Promises.zip(
  *rounds.map { |r| Concurrent::Promises.future { algod.block(r) } }
).value!

# Each block fetched in parallel (up to 30 at once)
```

#### Indexer Path
```ruby
# Paginated search with pre-filters
loop do
  result = indexer.search_transactions(
    min_round: start,
    max_round: end,
    next_token: next_token,
    # Pre-filters reduce data transfer
    tx_type: filter.type,
    address: filter.sender || filter.receiver,
    asset_id: filter.asset_id,
    application_id: filter.app_id
  )
  
  transactions.concat(result['transactions'])
  break unless result['next-token']
  next_token = result['next-token']
end
```

### Stage 2: Transformation

Convert algod blocks to indexer transaction format:

```ruby
def self.block_to_transactions(block_data)
  block = block_data['block']
  transactions = []
  
  # Process top-level transactions
  (block['txns'] || []).each_with_index do |txn, idx|
    transaction = algod_to_indexer_format(txn, block, idx)
    
    # Process inner transactions recursively
    if txn['dt']
      transaction['inner-txns'] = process_inner_txns(txn['dt'], block)
    end
    
    transactions << transaction
  end
  
  transactions
end
```

### Stage 3: Enhancement

Add computed fields:

```ruby
# Balance changes
transaction['balance-changes'] = Transform.extract_balance_changes(transaction)

# ARC-28 events
transaction['arc28-events'] = Transform.extract_arc28_events(transaction, event_defs)

# Block metadata
transaction['block-metadata'] = {
  round: block.round,
  timestamp: block.timestamp,
  genesis_id: block.genesis_id,
  genesis_hash: block.genesis_hash
}
```

### Stage 4: Filtering

Apply all filter criteria:

```ruby
def matches?(transaction)
  return false unless type_matches?(transaction)
  return false unless sender_matches?(transaction)
  return false unless receiver_matches?(transaction)
  return false unless amount_matches?(transaction)
  return false unless balance_changes_match?(transaction)
  return false unless arc28_events_match?(transaction)
  return false unless custom_filter_matches?(transaction)
  
  true
end
```

## Sync Strategies Internals

### Catchup with Indexer

```ruby
def catchup_with_indexer(watermark, current_round, config, algod, indexer)
  gap = current_round - watermark
  
  if gap > config.max_rounds_to_sync
    # Use indexer for large gaps
    end_round = watermark + config.max_indexer_rounds_to_sync
    get_indexer_subscribed_transactions(
      from_round: watermark + 1,
      to_round: end_round,
      config: config,
      indexer: indexer
    )
  else
    # Use algod for small gaps
    end_round = watermark + config.max_rounds_to_sync
    get_algod_subscribed_transactions(
      from_round: watermark + 1,
      to_round: end_round,
      config: config,
      algod: algod
    )
  end
end
```

### Sync Oldest Start Now

```ruby
def sync_oldest_start_now(watermark, current_round, config, algod)
  if watermark == 0
    # First run: skip to current
    return SubscriptionResult.new(
      starting_watermark: 0,
      new_watermark: current_round,
      synced_round_range: [],
      current_round: current_round,
      subscribed_transactions: []
    )
  else
    # Subsequent runs: sync from watermark
    sync_oldest(watermark, current_round, config, algod)
  end
end
```

## Balance Change Algorithm

Balance changes are calculated by traversing the transaction tree and summing all ALGO and asset movements.

### Algorithm

```ruby
def self.extract_balance_changes(transaction)
  changes = {}  # { "address:asset_id" => BalanceChange }
  
  # Process main transaction
  process_transaction(transaction, changes)
  
  # Process inner transactions recursively
  process_inner_transactions(transaction['inner-txns'] || [], changes)
  
  # Convert to array
  changes.values
end

def self.process_transaction(txn, changes)
  case txn['tx-type']
  when 'pay'
    # Sender loses ALGO
    add_change(changes, txn['sender'], 0, -txn['fee'] - amount, ['Sender'])
    
    # Receiver gains ALGO
    add_change(changes, receiver, 0, amount, ['Receiver'])
    
    # CloseTo receives remainder
    if close_to
      add_change(changes, close_to, 0, close_amount, ['CloseTo'])
    end
    
  when 'axfer'
    # Asset transfer logic
    add_change(changes, sender, asset_id, -amount, ['Sender'])
    add_change(changes, receiver, asset_id, amount, ['Receiver'])
    
  when 'acfg'
    # Asset creation/destruction
    if created_asset
      add_change(changes, creator, asset_id, total, ['AssetCreator'])
    end
    
  # ... other transaction types
  end
end
```

### Handling Inner Transactions

Inner transactions are processed recursively:

```ruby
def self.process_inner_transactions(inner_txns, changes)
  inner_txns.each do |inner_txn|
    process_transaction(inner_txn, changes)
    
    # Recursive for nested inner transactions
    if inner_txn['inner-txns']
      process_inner_transactions(inner_txn['inner-txns'], changes)
    end
  end
end
```

### Deduplication

Changes for the same address and asset are accumulated:

```ruby
def self.add_change(changes, address, asset_id, amount, roles)
  key = "#{address}:#{asset_id}"
  
  if changes[key]
    changes[key].amount += amount
    changes[key].roles.concat(roles).uniq!
  else
    changes[key] = BalanceChange.new(
      address: address,
      asset_id: asset_id,
      amount: amount,
      roles: roles
    )
  end
end
```

## ARC-28 Event Parsing

ARC-28 events are emitted via application logs using a standardized format.

### Event Format

```
Log Format: [4-byte selector][ABI-encoded arguments]

Selector: First 4 bytes of SHA-512/256(signature)
Signature: EventName(arg1Type,arg2Type,...)
```

### Parsing Algorithm

```ruby
def self.extract_arc28_events(transaction, event_definitions)
  logs = transaction.dig('logs') || []
  events = []
  
  logs.each do |log|
    # Decode base64 log
    log_data = Base64.decode64(log)
    next if log_data.length < 4
    
    # Extract 4-byte selector
    selector = log_data[0..3]
    
    # Find matching event definition
    event_def = find_event_by_selector(selector, event_definitions)
    next unless event_def
    
    # Decode arguments
    args_data = log_data[4..]
    args = decode_abi_args(args_data, event_def.args)
    
    events << Arc28Event.new(
      group_name: event_def.group_name,
      event_name: event_def.name,
      event_signature: event_def.signature,
      args: args
    )
  end
  
  events
end
```

### ABI Decoding

```ruby
def self.decode_abi_args(data, arg_definitions)
  offset = 0
  args = {}
  
  arg_definitions.each do |arg_def|
    value, bytes_read = decode_abi_type(data[offset..], arg_def.type)
    args[arg_def.name] = value
    offset += bytes_read
  end
  
  args
end

def self.decode_abi_type(data, type)
  case type
  when 'uint64'
    [data[0..7].unpack1('Q>'), 8]
  when 'address'
    [encode_address(data[0..31]), 32]
  when 'string'
    length = data[0..1].unpack1('n')
    [data[2...(2 + length)], 2 + length]
  # ... other types
  end
end
```

## Performance Characteristics

### Algod Sync Performance

- **Parallel Fetching:** Up to 30 blocks fetched concurrently
- **Throughput:** ~30 rounds/second with parallel fetching
- **Memory:** Processes in chunks, no accumulation
- **Optimal Range:** 30-100 rounds per sync

### Indexer Sync Performance

- **Pagination:** 1000 transactions per request
- **Pre-filtering:** Reduces network transfer by 50-90%
- **Throughput:** 10,000+ transactions/second
- **Optimal Range:** 1000-2000 rounds per sync

### Memory Usage

```
Base overhead: ~10 MB
Per transaction in memory: ~5 KB
Per round (avg 20 txns): ~100 KB

Example:
- 100 rounds = ~10 MB
- 1000 rounds = ~100 MB
- Processes in batches, releases after processing
```

### CPU Usage

```
Idle (at tip, wait-for-block): ~0-1% CPU
Active sync: ~10-30% CPU (single core)
Event processing: Depends on handlers (async)
```

### Network Usage

```
Algod block fetch: ~50 KB per block
Indexer search (1000 txns): ~500 KB - 5 MB
Pre-filters reduce by 50-90%
```

## Design Decisions

### Why Thread-Based Concurrency?

**Decision:** Use Ruby threads with concurrent-ruby primitives

**Rationale:**
- Ruby 3.1+ has improved thread performance
- Simpler than Fiber-based async
- Good enough for I/O-bound operations
- Compatible with most Ruby environments

**Trade-offs:**
- GIL limits CPU parallelism (not an issue for I/O-bound work)
- Thread overhead minimal for event handlers
- concurrent-ruby provides solid primitives

### Why Event Emitter Pattern?

**Decision:** Node.js-style event emitter

**Rationale:**
- Familiar pattern for many developers
- Decouples subscriber from business logic
- Supports multiple handlers per event
- Easy to test and extend

**Trade-offs:**
- Async by default (handlers in threads)
- Error in one handler doesn't affect others
- No backpressure control (handlers must be fast)

### Why Watermark-Based Sync?

**Decision:** Single watermark for all filters

**Rationale:**
- Simple to understand and implement
- Guarantees no missed transactions
- Enables crash recovery
- Works with all sync strategies

**Trade-offs:**
- All filters sync at same pace
- Can't skip ranges
- Must process sequentially

### Why Both Algod and Indexer?

**Decision:** Support both, make indexer optional

**Rationale:**
- Indexer not always available
- Algod-only works for real-time monitoring
- Indexer much faster for historical catchup
- Hybrid approach gives best of both

**Trade-offs:**
- More complex implementation
- Two code paths to maintain
- Additional client configuration

### Why Parallel Block Fetching?

**Decision:** Fetch up to 30 blocks concurrently from algod

**Rationale:**
- Algod block endpoint is fast
- Network latency is bottleneck
- 30x speedup with parallel fetching
- Safe (blocks immutable once confirmed)

**Trade-offs:**
- More concurrent connections
- Slightly higher memory usage
- Must handle partial failures

### Why Transform Algod to Indexer Format?

**Decision:** Convert algod blocks to indexer transaction format

**Rationale:**
- Single format simplifies filtering logic
- Indexer format more complete/convenient
- Easier for users (one format to learn)
- Can switch between algod/indexer transparently

**Trade-offs:**
- Conversion overhead
- Must maintain mapping logic
- Some algod-specific data lost

## Extension Points

The architecture supports several extension points:

### Custom Filters

```ruby
filter = {
  custom_filter: ->(txn) {
    # Your custom logic
    your_complex_matching_logic(txn)
  }
}
```

### Custom Watermark Storage

```ruby
watermark_persistence = {
  get: -> { your_storage.get_watermark },
  set: ->(w) { your_storage.set_watermark(w) }
}
```

### Custom Event Handlers

```ruby
subscriber.on('filter-name') do |txn|
  # Your custom processing
  YourService.process(txn)
end
```

### Custom Clients

You can subclass the clients to add custom behavior:

```ruby
class CustomAlgodClient < Algokit::Subscriber::Client::AlgodClient
  def block(round)
    # Add caching, metrics, etc.
    super
  end
end
```

## Testing Architecture

The gem has comprehensive test coverage:

- **Unit Tests:** Test individual components in isolation
- **Integration Tests:** Test with VCR-recorded API responses
- **Feature Tests:** End-to-end subscriber scenarios

**Key Testing Patterns:**
- VCR for HTTP mocking
- Fixtures for test data
- Concurrent testing with multiple threads

## Future Improvements

Potential areas for enhancement:

1. **Connection Pooling:** Better HTTP connection reuse
2. **Caching Layer:** Cache blocks/transactions
3. **Metrics Built-in:** Built-in Prometheus/StatsD support
4. **GraphQL Support:** When Algorand adds GraphQL API
5. **Stream API:** Real-time streaming when available
6. **Per-Filter Watermarks:** Independent watermarks per filter
7. **Backpressure:** Handle slow event handlers better
