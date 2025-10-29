# AlgoKit Subscriber Examples

This directory contains working examples demonstrating different use cases and configurations.

## Quick Start Examples

### 1. Simple Payment Tracker
**File**: `simple_payment_tracker.rb`

The simplest possible example - tracks ALGO payments over 1 ALGO.

```bash
ruby examples/simple_payment_tracker.rb
```

**Features**:
- Basic payment filtering
- Real-time monitoring
- Algod only

---

## USDC Tracking Examples

### 2. USDC Monitoring (with Indexer)
**File**: `usdc_monitoring.rb`

Full-featured USDC tracker with indexer support for fast historical catchup.

```bash
ruby examples/usdc_monitoring.rb
```

**Features**:
- Tracks all USDC transfers
- Highlights large transfers (>1 USDC)
- SYNC_OLDEST_START_NOW behavior
- Indexer support (optional)
- Watermark persistence

**Best for**: Development and testing with historical data

---

### 3. USDC Monitoring (Algod Only)
**File**: `usdc_monitoring_algod_only.rb`

Same as above but using ONLY algod (no indexer required).

```bash
ruby examples/usdc_monitoring_algod_only.rb
```

**Features**:
- Algod only (no indexer needed)
- SYNC_OLDEST_START_NOW behavior
- Catches up on missed transactions after restart
- Watermark persistence

**Best for**: Lightweight deployments without indexer

---

### 4. USDC Tracking (Skip Sync Newest)
**File**: `usdc_tracking_skip_sync.rb`

Real-time only USDC tracker that skips all historical data.

```bash
ruby examples/usdc_tracking_skip_sync.rb
```

**Features**:
- SKIP_SYNC_NEWEST behavior
- Jumps immediately to latest round
- Algod only
- Tracks both transfers and opt-ins
- Custom transaction mapping
- Zero startup time

**Best for**: Real-time alerting and monitoring when historical data is not needed

---

## Advanced Examples

### 5. Data History Museum (DHM)
**File**: `data_history_museum.rb`

Monitors the Data History Museum NFT collection on TestNet.

```bash
ruby examples/data_history_museum.rb
```

**Features**:
- Asset creation tracking
- Asset transfer monitoring
- Multiple filter demonstration
- Real-world NFT use case

---

### 6. ARC-28 Event Listener
**File**: `arc28_event_listener.rb`

Demonstrates listening to ARC-28 standardized events from smart contracts.

```bash
ruby examples/arc28_event_listener.rb
```

**Features**:
- ARC-28 event parsing
- Smart contract log filtering
- Event argument extraction
- Mock event generation for testing

---

### 7. Performance Benchmark
**File**: `performance_benchmark.rb`

Benchmarks different sync strategies and measures performance.

```bash
ruby examples/performance_benchmark.rb
```

**Features**:
- Compares algod vs indexer performance
- Measures throughput
- Tests different round ranges
- Performance metrics

---

## Comparison: USDC Examples

| Example                       | Indexer | Startup  | Historical | Downtime Recovery | Use Case                    |
|-------------------------------|---------|----------|------------|-------------------|-----------------------------|
| `usdc_monitoring.rb`          | Yes     | Instant  | ✓ Fast     | ✓ Full catchup    | Production with history     |
| `usdc_monitoring_algod_only.rb` | No    | Instant  | ✓ Slow     | ✓ Full catchup    | Lightweight production      |
| `usdc_tracking_skip_sync.rb`  | No      | Instant  | ✗ None     | ✗ Missed          | Real-time monitoring only   |

## Configuration Options

All examples can be configured via environment variables:

```bash
# Algod configuration
export ALGOD_SERVER="https://testnet-api.algonode.cloud"
export ALGOD_TOKEN=""  # Optional

# Indexer configuration (if used)
export INDEXER_SERVER="https://testnet-idx.algonode.cloud"
export INDEXER_TOKEN=""  # Optional
```

## Running Examples

### Basic Usage
```bash
ruby examples/simple_payment_tracker.rb
```

### With Custom Algod Server
```bash
ALGOD_SERVER="http://localhost:4001" ALGOD_TOKEN="your-token" \
  ruby examples/usdc_tracking_skip_sync.rb
```

### Stop Examples
Press `Ctrl+C` to gracefully stop any example. They will show session statistics before exiting.

## Learn More

- **Sync Behaviors**: See `SYNC_BEHAVIORS.md` for detailed explanation of sync strategies
- **Main README**: See `../README.md` for library documentation
- **API Reference**: Check the main README for complete API documentation

## Need Help?

- Check the comments in each example file
- Read `SYNC_BEHAVIORS.md` to understand sync strategies
- See the main README for troubleshooting
- Open an issue on GitHub
