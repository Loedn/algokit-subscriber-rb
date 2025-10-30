# Advanced Usage Guide

Advanced patterns, optimization techniques, and production deployment strategies for AlgoKit Subscriber.

## Table of Contents

- [Advanced Filtering](#advanced-filtering)
- [Balance Change Tracking](#balance-change-tracking)
- [ARC-28 Event Processing](#arc-28-event-processing)
- [Sync Strategies](#sync-strategies)
- [Watermark Persistence](#watermark-persistence)
- [Performance Optimization](#performance-optimization)
- [Error Handling](#error-handling)
- [Production Deployment](#production-deployment)
- [Monitoring & Observability](#monitoring--observability)

## Advanced Filtering

### Combining Multiple Criteria

You can combine multiple filter criteria to create precise matching rules:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'large-usdc-to-treasury',
      filter: {
        type: 'axfer',
        asset_id: 10458941,           # USDC
        receiver: 'TREASURY_ADDRESS',  # To specific address
        min_amount: 100_000_000       # At least 100 USDC
      }
    }
  ]
)
```

### Custom Filter Functions

For complex logic, use custom filter functions:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'suspicious-payments',
      filter: {
        type: 'pay',
        custom_filter: lambda do |txn|
          # Match payments that:
          # 1. Are exactly 1.234 ALGO
          # 2. Have a specific note pattern
          # 3. Happen during business hours (UTC)
          
          amount = txn.dig('payment-transaction', 'amount')
          note = txn['note']
          time = Time.at(txn['round-time'])
          
          amount == 1_234_000 &&
            note&.include?('special') &&
            time.hour >= 9 && time.hour < 17
        end
      }
    }
  ]
)
```

### Multiple Filters for Same Transaction Type

Create different handlers for different scenarios:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'small-payments',
      filter: {
        type: 'pay',
        min_amount: 1_000_000,     # 1 ALGO
        max_amount: 10_000_000     # 10 ALGO
      }
    },
    {
      name: 'large-payments',
      filter: {
        type: 'pay',
        min_amount: 10_000_000     # 10+ ALGO
      }
    },
    {
      name: 'vip-payments',
      filter: {
        type: 'pay',
        sender: 'VIP_ADDRESS',
        min_amount: 1              # Any amount from VIP
      }
    }
  ]
)

subscriber.on('small-payments') { |txn| log_normal(txn) }
subscriber.on('large-payments') { |txn| alert_large(txn) }
subscriber.on('vip-payments') { |txn| alert_vip(txn) }
```

### Method Signature Filtering (ARC-4)

Filter smart contract calls by ARC-4 method signature:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'swap-calls',
      filter: {
        type: 'appl',
        app_id: 123456,
        method_signature: 'swap(uint64,uint64)uint64'
      }
    }
  ]
)
```

### Note Prefix Filtering

Filter by transaction note prefix:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'app-payments',
      filter: {
        type: 'pay',
        note_prefix: Base64.strict_encode64('myapp:')
      }
    }
  ]
)
```

## Balance Change Tracking

Balance change tracking automatically calculates net balance changes for addresses, including inner transactions.

### Basic Balance Tracking

Track when an address receives or sends funds:

```ruby
WALLET = 'YOUR_ADDRESS_HERE'

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'wallet-activity',
      filter: {
        balance_changes: [
          {
            address: WALLET,
            min_absolute_amount: 1  # Any change
          }
        ]
      }
    }
  ]
)

subscriber.on('wallet-activity') do |txn|
  changes = txn['balance-changes'] || []
  wallet_change = changes.find { |c| c.address == WALLET }
  
  puts "Transaction: #{txn['id']}"
  puts "  Net change: #{wallet_change.amount} microAlgos"
  puts "  Roles: #{wallet_change.roles.join(', ')}"
end
```

### Track Multiple Assets

Monitor ALGO and multiple asset balances for an address:

```ruby
TREASURY = 'TREASURY_ADDRESS'
USDC_ID = 10458941
TOKEN_ID = 123456

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'treasury-changes',
      filter: {
        balance_changes: [
          # ALGO changes
          {
            address: TREASURY,
            asset_id: 0,
            min_absolute_amount: 1_000_000
          },
          # USDC changes
          {
            address: TREASURY,
            asset_id: USDC_ID,
            min_absolute_amount: 1_000_000
          },
          # Custom token changes
          {
            address: TREASURY,
            asset_id: TOKEN_ID,
            min_absolute_amount: 1
          }
        ]
      }
    }
  ]
)

subscriber.on('treasury-changes') do |txn|
  changes = txn['balance-changes'] || []
  
  changes.each do |change|
    next unless change.address == TREASURY
    
    asset_name = case change.asset_id
                 when 0 then 'ALGO'
                 when USDC_ID then 'USDC'
                 when TOKEN_ID then 'TOKEN'
                 else "Asset #{change.asset_id}"
                 end
    
    puts "#{asset_name}: #{change.amount} (#{change.roles.join(', ')})"
  end
end
```

### Filter by Role

Track only specific roles (Sender, Receiver, CloseTo, etc.):

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [
    {
      name: 'treasury-deposits',
      filter: {
        balance_changes: [
          {
            address: TREASURY,
            roles: ['Receiver', 'CloseTo'],  # Only deposits
            min_amount: 1_000_000
          }
        ]
      }
    },
    {
      name: 'treasury-withdrawals',
      filter: {
        balance_changes: [
          {
            address: TREASURY,
            roles: ['Sender'],  # Only withdrawals
            max_amount: -1_000_000  # Negative amount = sending
          }
        ]
      }
    }
  ]
)
```

### Complex Balance Scenarios

Handle complex scenarios with inner transactions:

```ruby
subscriber.on('treasury-changes') do |txn|
  changes = txn['balance-changes'] || []
  
  # Group changes by asset
  by_asset = changes.group_by(&:asset_id)
  
  by_asset.each do |asset_id, asset_changes|
    # Calculate net change across all addresses
    net = asset_changes.sum(&:amount)
    
    # Get treasury-specific changes
    treasury_changes = asset_changes.select { |c| c.address == TREASURY }
    treasury_net = treasury_changes.sum(&:amount)
    
    asset_name = asset_id == 0 ? 'ALGO' : "Asset #{asset_id}"
    
    puts "#{asset_name}:"
    puts "  Treasury net: #{treasury_net}"
    puts "  Transaction net: #{net}"
    puts "  Details:"
    treasury_changes.each do |change|
      puts "    #{change.amount} (#{change.roles.join(', ')})"
    end
  end
end
```

## ARC-28 Event Processing

ARC-28 is the standard for Algorand smart contract events.

### Define Event Schema

First, define your event schemas:

```ruby
# Define event groups
dex_events = Algokit::Subscriber::Types::Arc28EventGroup.new(
  group_name: 'DEX',
  events: [
    {
      name: 'Swap',
      args: [
        { name: 'trader', type: 'address' },
        { name: 'tokenIn', type: 'uint64' },
        { name: 'amountIn', type: 'uint64' },
        { name: 'tokenOut', type: 'uint64' },
        { name: 'amountOut', type: 'uint64' },
        { name: 'timestamp', type: 'uint64' }
      ]
    },
    {
      name: 'AddLiquidity',
      args: [
        { name: 'provider', type: 'address' },
        { name: 'amountA', type: 'uint64' },
        { name: 'amountB', type: 'uint64' },
        { name: 'lpTokens', type: 'uint64' }
      ]
    },
    {
      name: 'RemoveLiquidity',
      args: [
        { name: 'provider', type: 'address' },
        { name: 'lpTokens', type: 'uint64' },
        { name: 'amountA', type: 'uint64' },
        { name: 'amountB', type: 'uint64' }
      ]
    }
  ]
)
```

### Filter by Events

Filter transactions that emit specific events:

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
    },
    {
      name: 'dex-liquidity',
      filter: {
        type: 'appl',
        app_id: 789,
        arc28_events: [
          { group_name: 'DEX', event_name: 'AddLiquidity' },
          { group_name: 'DEX', event_name: 'RemoveLiquidity' }
        ]
      }
    }
  ],
  arc28_events: [dex_events]
)
```

### Process Events

Handle the parsed events:

```ruby
subscriber.on('dex-swaps') do |txn|
  events = txn['arc28-events'] || []
  
  events.each do |event|
    next unless event.event_name == 'Swap'
    
    trader = event.args['trader']
    token_in = event.args['tokenIn']
    amount_in = event.args['amountIn']
    token_out = event.args['tokenOut']
    amount_out = event.args['amountOut']
    timestamp = event.args['timestamp']
    
    puts "Swap Event:"
    puts "  Trader: #{trader}"
    puts "  Swapped: #{amount_in} of Asset #{token_in}"
    puts "  Received: #{amount_out} of Asset #{token_out}"
    puts "  Time: #{Time.at(timestamp)}"
    
    # Store in database, send notification, etc.
    save_swap_to_db(trader, token_in, amount_in, token_out, amount_out)
  end
end
```

### Multiple Event Groups

Organize events into logical groups:

```ruby
# DEX events
dex_events = Algokit::Subscriber::Types::Arc28EventGroup.new(
  group_name: 'DEX',
  events: [...]
)

# Governance events
governance_events = Algokit::Subscriber::Types::Arc28EventGroup.new(
  group_name: 'Governance',
  events: [
    {
      name: 'ProposalCreated',
      args: [
        { name: 'proposalId', type: 'uint64' },
        { name: 'creator', type: 'address' },
        { name: 'description', type: 'string' }
      ]
    },
    {
      name: 'VoteCast',
      args: [
        { name: 'proposalId', type: 'uint64' },
        { name: 'voter', type: 'address' },
        { name: 'support', type: 'bool' },
        { name: 'weight', type: 'uint64' }
      ]
    }
  ]
)

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  arc28_events: [dex_events, governance_events]
)
```

## Sync Strategies

Choose the right sync strategy for your use case.

### Strategy 1: Catchup with Indexer (Default)

Best for production with historical data needs.

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::CATCHUP_WITH_INDEXER
)

subscriber = Algokit::Subscriber::AlgorandSubscriber.new(
  config,
  algod,
  indexer  # Required for this strategy
)
```

**When to use:**
- Production deployments
- Need fast historical catchup
- Have access to indexer
- Want optimal performance

### Strategy 2: Sync Oldest Start Now

Start fresh, but catch up after restarts.

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST_START_NOW,
  watermark_persistence: {
    get: -> { File.read('watermark.txt').to_i rescue 0 },
    set: ->(w) { File.write('watermark.txt', w.to_s) }
  }
)
```

**When to use:**
- Development/testing
- Don't need historical data initially
- Want automatic recovery after crashes
- Algod-only setup

### Strategy 3: Skip Sync Newest

Real-time only, never sync history.

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST,
  wait_for_block_when_at_tip: true  # Low latency
)
```

**When to use:**
- Real-time alerting
- Don't care about missed transactions
- Minimum latency required
- Monitoring dashboards

### Strategy 4: Sync Oldest

Process all history from watermark.

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST,
  max_rounds_to_sync: 1000  # Process in batches
)
```

**When to use:**
- Archival analysis
- Need complete transaction history
- Data integrity critical
- Have time for initial sync

### Strategy 5: Fail

Fail fast if behind.

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::FAIL
)
```

**When to use:**
- Critical monitoring
- Cannot tolerate delays
- Want to be alerted to problems
- Manual recovery preferred

## Watermark Persistence

Watermarks track the last processed round, enabling crash recovery.

### File-Based Persistence

Simple file storage:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  watermark_persistence: {
    get: -> { File.read('watermark.txt').to_i rescue 0 },
    set: ->(w) { File.write('watermark.txt', w.to_s) }
  }
)
```

### Database Persistence

Store in database (ActiveRecord example):

```ruby
# Migration
class CreateWatermarks < ActiveRecord::Migration[7.0]
  def change
    create_table :watermarks do |t|
      t.integer :round, null: false
      t.timestamps
    end
  end
end

# Model
class Watermark < ApplicationRecord
  validates :round, presence: true
end

# Configuration
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  watermark_persistence: {
    get: -> { Watermark.last&.round || 0 },
    set: ->(w) { Watermark.create!(round: w) }
  }
)
```

### Redis Persistence

Store in Redis:

```ruby
require 'redis'

redis = Redis.new(url: ENV['REDIS_URL'])

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  watermark_persistence: {
    get: -> { (redis.get('algorand:watermark') || 0).to_i },
    set: ->(w) { redis.set('algorand:watermark', w) }
  }
)
```

### Per-Filter Watermarks

Track watermarks separately for each filter:

```ruby
class WatermarkStore
  def initialize(redis)
    @redis = redis
  end
  
  def get_watermark(filter_name)
    (@redis.get("watermark:#{filter_name}") || 0).to_i
  end
  
  def set_watermark(filter_name, round)
    @redis.set("watermark:#{filter_name}", round)
  end
  
  # Return lowest watermark for subscriber
  def get
    filter_names = ['filter1', 'filter2', 'filter3']
    filter_names.map { |n| get_watermark(n) }.min || 0
  end
  
  def set(round)
    filter_names = ['filter1', 'filter2', 'filter3']
    filter_names.each { |n| set_watermark(n, round) }
  end
end

store = WatermarkStore.new(redis)

config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  watermark_persistence: {
    get: -> { store.get },
    set: ->(w) { store.set(w) }
  }
)
```

## Performance Optimization

### Optimize Polling Frequency

Balance freshness vs load:

```ruby
# High-frequency (more load, lower latency)
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  frequency_in_seconds: 0.5,
  wait_for_block_when_at_tip: true
)

# Low-frequency (less load, higher latency)
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  frequency_in_seconds: 5.0,
  wait_for_block_when_at_tip: false
)
```

### Optimize Batch Size

Tune rounds per sync:

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  max_rounds_to_sync: 30,           # Smaller for faster processing
  max_indexer_rounds_to_sync: 2000  # Larger for indexer (faster)
)
```

### Use Batch Processing

Process transactions in batches:

```ruby
subscriber.on_batch('payments') do |transactions|
  # Bulk insert to database
  Payment.insert_all(
    transactions.map do |txn|
      {
        txn_id: txn['id'],
        amount: txn.dig('payment-transaction', 'amount'),
        sender: txn['sender'],
        receiver: txn.dig('payment-transaction', 'receiver'),
        round: txn['confirmed-round']
      }
    end
  )
end
```

### Parallel Processing

Process different filters in parallel:

```ruby
subscriber.on('payments') do |txn|
  # Process asynchronously
  PaymentProcessor.perform_async(txn)
end

subscriber.on('asset-transfers') do |txn|
  AssetTransferProcessor.perform_async(txn)
end
```

### Connection Pooling

Reuse HTTP connections:

```ruby
# The gem uses Faraday with connection pooling by default
# For custom configuration:

require 'faraday'
require 'faraday/retry'

connection = Faraday.new(url: 'https://testnet-api.algonode.cloud') do |f|
  f.request :retry, max: 3, interval: 0.5
  f.adapter :net_http do |http|
    http.max_connections = 10  # Connection pool size
  end
end

# Note: This is handled automatically by the gem
```

## Error Handling

### Basic Error Handling

Catch and log errors:

```ruby
subscriber.on_error do |error|
  puts "Error: #{error.class} - #{error.message}"
  puts error.backtrace.first(5).join("\n")
  
  # Don't re-raise, subscriber will continue
end
```

### Error Classification

Handle different error types:

```ruby
subscriber.on_error do |error|
  case error
  when Algokit::Subscriber::ClientError
    # API errors (4xx, 5xx)
    puts "API Error: #{error.message}"
    ErrorTracker.notify(error, severity: 'warning')
    
  when Algokit::Subscriber::TimeoutError
    # Request timeout
    puts "Timeout: #{error.message}"
    # Usually transient, no action needed
    
  when Algokit::Subscriber::ConfigurationError
    # Configuration problem
    puts "Config Error: #{error.message}"
    ErrorTracker.notify(error, severity: 'critical')
    subscriber.stop('Configuration error')
    
  else
    # Unknown error
    puts "Unexpected Error: #{error.class}"
    ErrorTracker.notify(error, severity: 'error')
  end
end
```

### Retry Logic

Implement custom retry for transient errors:

```ruby
MAX_RETRIES = 3
retry_count = 0

subscriber.on_error do |error|
  if error.is_a?(Algokit::Subscriber::TimeoutError)
    retry_count += 1
    
    if retry_count <= MAX_RETRIES
      puts "Retry #{retry_count}/#{MAX_RETRIES}"
      sleep(2 ** retry_count)  # Exponential backoff
      # Subscriber will automatically retry
    else
      puts "Max retries exceeded"
      subscriber.stop('Too many failures')
    end
  else
    retry_count = 0
    ErrorTracker.notify(error)
  end
end

# Reset retry count on successful poll
subscriber.on_poll do |result|
  retry_count = 0 if retry_count > 0
end
```

### Circuit Breaker Pattern

Stop processing after repeated failures:

```ruby
class CircuitBreaker
  def initialize(threshold: 5, timeout: 60)
    @threshold = threshold
    @timeout = timeout
    @failures = 0
    @last_failure = nil
    @open = false
  end
  
  def record_failure
    @failures += 1
    @last_failure = Time.now
    
    if @failures >= @threshold
      @open = true
      puts "Circuit breaker OPEN (#{@failures} failures)"
    end
  end
  
  def record_success
    @failures = 0
    @open = false
  end
  
  def should_allow?
    return true unless @open
    
    # Try again after timeout
    if Time.now - @last_failure > @timeout
      puts "Circuit breaker trying to close..."
      @open = false
      @failures = 0
      true
    else
      false
    end
  end
end

breaker = CircuitBreaker.new

subscriber.on_error do |error|
  breaker.record_failure
  
  if !breaker.should_allow?
    puts "Circuit breaker is OPEN, stopping subscriber"
    subscriber.stop('Circuit breaker open')
  end
end

subscriber.on_poll do |result|
  breaker.record_success
end
```

## Production Deployment

### Deployment Checklist

- [ ] Use indexer for faster catchup
- [ ] Configure watermark persistence
- [ ] Set up error tracking (Sentry, Rollbar, etc.)
- [ ] Configure logging
- [ ] Set appropriate polling frequency
- [ ] Test failover and recovery
- [ ] Monitor performance metrics
- [ ] Set up health checks
- [ ] Configure graceful shutdown
- [ ] Document runbooks

### Graceful Shutdown

Handle shutdown signals:

```ruby
# Handle multiple signals
['INT', 'TERM', 'QUIT'].each do |signal|
  Signal.trap(signal) do
    puts "\nReceived #{signal}, shutting down..."
    subscriber.stop("Signal #{signal}")
    
    # Cleanup
    redis.quit if defined?(redis)
    db.disconnect if defined?(db)
    
    exit 0
  end
end
```

### Health Checks

Implement health check endpoint:

```ruby
require 'webrick'

health_status = {
  running: false,
  last_poll: nil,
  error: nil
}

subscriber.on_poll do |result|
  health_status[:running] = true
  health_status[:last_poll] = Time.now
  health_status[:error] = nil
end

subscriber.on_error do |error|
  health_status[:error] = error.message
end

# Health check server
server = WEBrick::HTTPServer.new(Port: 3000)
server.mount_proc '/health' do |req, res|
  if health_status[:running] && 
     health_status[:last_poll] && 
     Time.now - health_status[:last_poll] < 30
    res.status = 200
    res.body = 'OK'
  else
    res.status = 503
    res.body = "Error: #{health_status[:error] || "Not polling"}"
  end
end

Thread.new { server.start }
```

### Containerization (Docker)

Example Dockerfile:

```dockerfile
FROM ruby:3.2-slim

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["ruby", "subscriber.rb"]
```

Docker Compose:

```yaml
version: '3.8'

services:
  subscriber:
    build: .
    environment:
      - ALGOD_SERVER=https://testnet-api.algonode.cloud
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    restart: unless-stopped
  
  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data
    restart: unless-stopped

volumes:
  redis-data:
```

### Systemd Service

Example systemd unit:

```ini
[Unit]
Description=Algorand Subscriber
After=network.target

[Service]
Type=simple
User=algorand
WorkingDirectory=/opt/subscriber
Environment="ALGOD_SERVER=https://mainnet-api.algonode.cloud"
Environment="REDIS_URL=redis://localhost:6379"
ExecStart=/usr/local/bin/ruby subscriber.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Monitoring & Observability

### Structured Logging

Use structured logging for better observability:

```ruby
require 'logger'
require 'json'

class StructuredLogger < Logger
  def format_message(severity, timestamp, progname, msg)
    {
      timestamp: timestamp.iso8601,
      severity: severity,
      message: msg
    }.to_json + "\n"
  end
end

Algokit::Subscriber.logger = StructuredLogger.new($stdout)

subscriber.on_poll do |result|
  Algokit::Subscriber.logger.info({
    event: 'poll_complete',
    rounds_synced: result.rounds_synced,
    watermark: result.new_watermark,
    transactions: result.subscribed_transactions.sum { |s| s.transactions.length }
  }.to_json)
end
```

### Metrics Collection

Track key metrics:

```ruby
class Metrics
  def initialize
    @polls = 0
    @rounds_synced = 0
    @transactions_processed = 0
    @errors = 0
    @start_time = Time.now
  end
  
  def record_poll(result)
    @polls += 1
    @rounds_synced += result.rounds_synced
    @transactions_processed += result.subscribed_transactions.sum { |s| s.transactions.length }
  end
  
  def record_error
    @errors += 1
  end
  
  def summary
    uptime = Time.now - @start_time
    {
      uptime_seconds: uptime.to_i,
      polls: @polls,
      rounds_synced: @rounds_synced,
      transactions_processed: @transactions_processed,
      errors: @errors,
      avg_rounds_per_poll: @polls > 0 ? (@rounds_synced.to_f / @polls).round(2) : 0,
      avg_txns_per_poll: @polls > 0 ? (@transactions_processed.to_f / @polls).round(2) : 0
    }
  end
end

metrics = Metrics.new

subscriber.on_poll { |result| metrics.record_poll(result) }
subscriber.on_error { |error| metrics.record_error }

# Print summary periodically
Thread.new do
  loop do
    sleep 60
    puts "Metrics: #{metrics.summary.inspect}"
  end
end
```

### Integration with APM Tools

Example with StatsD:

```ruby
require 'statsd-instrument'

StatsD.backend = StatsD::Instrument::Backends::UDPBackend.new('localhost:8125', :datadog)

subscriber.on_poll do |result|
  StatsD.gauge('subscriber.watermark', result.new_watermark)
  StatsD.increment('subscriber.polls')
  StatsD.histogram('subscriber.rounds_synced', result.rounds_synced)
  StatsD.histogram('subscriber.transactions', 
    result.subscribed_transactions.sum { |s| s.transactions.length })
end

subscriber.on_error do |error|
  StatsD.increment('subscriber.errors', tags: ["error:#{error.class}"])
end
```

### Alerting

Set up alerts for critical issues:

```ruby
def send_alert(message)
  # Slack
  slack_webhook = ENV['SLACK_WEBHOOK_URL']
  # HTTP.post(slack_webhook, json: { text: message })
  
  # PagerDuty
  # PagerDuty.trigger(message)
  
  # Email
  # Mailer.alert(message).deliver
end

subscriber.on_error do |error|
  if error.is_a?(Algokit::Subscriber::ConfigurationError)
    send_alert("CRITICAL: Subscriber configuration error: #{error.message}")
  end
end

# Alert if no polls for too long
last_poll = Time.now

subscriber.on_poll { |result| last_poll = Time.now }

Thread.new do
  loop do
    sleep 60
    if Time.now - last_poll > 300  # 5 minutes
      send_alert("WARNING: No polls for 5 minutes")
    end
  end
end
```

## Best Practices Summary

1. **Always use watermark persistence in production**
2. **Use indexer for faster historical catchup**
3. **Implement proper error handling and alerting**
4. **Monitor key metrics (watermark, errors, throughput)**
5. **Test your subscriber on TestNet first**
6. **Use appropriate sync strategy for your use case**
7. **Implement graceful shutdown handling**
8. **Use batch processing for high throughput**
9. **Keep filters as specific as possible**
10. **Document your deployment and recovery procedures**
