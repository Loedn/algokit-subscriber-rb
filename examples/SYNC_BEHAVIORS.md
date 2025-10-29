# Sync Behavior Comparison for USDC Tracking

This document explains the different sync behaviors and when to use each one for tracking USDC transactions with algod only.

## Sync Behaviors Overview

### 1. SKIP_SYNC_NEWEST (Real-time Only)

**Use case**: You only care about NEW transactions from this moment forward.

```ruby
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST
```

**Behavior**:
- ✓ Jumps immediately to the current round
- ✓ Never syncs historical data
- ✓ Lowest latency for real-time monitoring
- ✗ Misses transactions that occurred before startup
- ✗ Misses transactions during downtime

**Example**: `examples/usdc_tracking_skip_sync.rb`

**Timeline**:
```
Round:     1000 ─────────────────> 2000 ─────────> 2005
                                    ↑               ↑
                                 Start here    Monitor these
                                 (skip 1000-2000)
```

### 2. SYNC_OLDEST_START_NOW (Historical Catchup + Real-time)

**Use case**: You want to sync historical data from a specific point, then continue real-time.

```ruby
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST_START_NOW
```

**Behavior**:
- ✓ First run: Starts from current round (like SKIP_SYNC_NEWEST)
- ✓ Subsequent runs: Syncs from watermark (catches up on missed transactions)
- ✓ Good for development/testing
- ✓ Recovers from downtime

**Example**: `examples/usdc_monitoring_algod_only.rb`

**Timeline**:
```
First Run:
Round:     1000 ─────────────────> 2000 ─────────> 2005
                                    ↑               ↑
                                 Start here    Monitor these

After Restart (watermark=2000):
Round:     1000 ───> 2000 ──> 2003 ──> 2005
                      ↑    Sync    ↑
                  Watermark    Current
                  (catch up on 2001-2005)
```

### 3. CATCHUP_WITH_INDEXER (Fast Catchup + Real-time)

**Use case**: You need to sync large gaps efficiently, then continue real-time.

```ruby
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::CATCHUP_WITH_INDEXER
```

**Behavior**:
- ✓ Uses indexer for large gaps (faster)
- ✓ Uses algod for small gaps and real-time
- ✓ Best for production with historical data
- ✗ Requires indexer (not algod-only)

**Example**: `examples/usdc_monitoring.rb` (requires indexer)

**Not available in algod-only mode** - needs indexer client.

### 4. SYNC_OLDEST (Complete Sync)

**Use case**: You need to process every single transaction from a specific round.

```ruby
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST
```

**Behavior**:
- ✓ Syncs ALL rounds from watermark to current
- ✓ No max_rounds_to_sync limit
- ✓ Guarantees no gaps
- ✗ Can be very slow for large gaps with algod only
- ⚠️ Use with indexer for large historical ranges

### 5. FAIL (Strict Mode)

**Use case**: You want to be alerted if the subscriber falls behind.

```ruby
sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::FAIL
```

**Behavior**:
- ✓ Fails immediately if watermark < current_round
- ✓ Ensures no transactions are missed
- ✓ Good for critical monitoring
- ✗ Requires manual intervention on failure

## Performance Comparison (Algod Only)

| Sync Behavior          | Startup Time | Historical Data | Downtime Recovery | Best For                |
|------------------------|--------------|-----------------|-------------------|-------------------------|
| SKIP_SYNC_NEWEST       | Instant      | ✗ None          | ✗ Missed          | Live monitoring only    |
| SYNC_OLDEST_START_NOW  | Instant      | ✓ After restart | ✓ Full catchup    | Development, testing    |
| SYNC_OLDEST            | Slow         | ✓ All           | ✓ Full catchup    | Complete historical     |
| FAIL                   | Instant      | ✗ Must be 0     | ✗ Fails           | Critical monitoring     |

## Recommendations

### Real-time Monitoring Only
Use **SKIP_SYNC_NEWEST** with algod only:
- Minimal latency
- No historical processing
- Perfect for alerting on new transactions

```ruby
# Example: Alert on large USDC transfers happening RIGHT NOW
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [{
    name: "large-usdc",
    filter: { type: "axfer", asset_id: 10458941, min_amount: 10_000_000 }
  }],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST,
  wait_for_block_when_at_tip: true # Low latency
)
```

### Development/Testing
Use **SYNC_OLDEST_START_NOW** with algod only:
- Quick startup
- Automatic catchup after restart
- No need for indexer

```ruby
config = Algokit::Subscriber::Types::SubscriptionConfig.new(
  filters: [...],
  sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST_START_NOW,
  max_rounds_to_sync: 10 # Process in small batches
)
```

### Production with Historical Data
Use **CATCHUP_WITH_INDEXER** with indexer:
- Fast catchup for large gaps
- Real-time monitoring at tip
- Best of both worlds

```ruby
# Requires indexer client
subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)
```

## Algod-Only Limitations

When using **algod only** (no indexer):

1. **Large historical ranges are slow**
   - Algod processes ~30 rounds/second in parallel
   - 10,000 rounds = ~5-6 minutes
   - 100,000 rounds = ~1 hour

2. **Use SKIP_SYNC_NEWEST or SYNC_OLDEST_START_NOW**
   - These behaviors work best with algod only
   - Avoid trying to sync millions of historical rounds

3. **For historical data, consider indexer**
   - Indexer can process 1000s of rounds instantly
   - Much faster for initial catchup

## Examples in this Repository

1. **`usdc_tracking_skip_sync.rb`** - SKIP_SYNC_NEWEST + algod only
2. **`usdc_monitoring_algod_only.rb`** - SYNC_OLDEST_START_NOW + algod only
3. **`usdc_monitoring.rb`** - SYNC_OLDEST_START_NOW + indexer (optional)

## Testing the Examples

```bash
# Real-time only (instant startup)
ruby examples/usdc_tracking_skip_sync.rb

# With catchup (restarts from watermark)
ruby examples/usdc_monitoring_algod_only.rb

# With indexer for fast catchup
ruby examples/usdc_monitoring.rb
```
