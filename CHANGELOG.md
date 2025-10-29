# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of algokit-subscriber Ruby gem
- HTTP clients for Algorand algod and indexer APIs
- Comprehensive transaction filtering (15+ filter types)
- Balance change tracking across all transaction types
- ARC-28 event parsing and filtering
- Multiple sync strategies (algod, indexer, hybrid)
- Event-driven subscriber with Node.js-style API
- Watermark-based crash recovery
- Wait-for-block low-latency mode
- Thread-safe implementation with concurrent-ruby
- 189 tests with 82% code coverage
- Complete examples (DHM, USDC monitoring, payments, ARC-28)
- Comprehensive documentation

### Features

#### HTTP Clients
- `AlgodClient` - Full algod API support (status, blocks, wait-for-block)
- `IndexerClient` - Transaction search with pagination
- Automatic retry with exponential backoff
- Custom headers and authentication
- Comprehensive error handling

#### Transaction Filtering
- Type filtering (pay, axfer, acfg, appl, keyreg, afrz)
- Address filtering (sender, receiver)
- Amount ranges (min/max)
- Application and asset filtering
- Note prefix matching
- Method signature matching (ARC-4)
- Balance change filtering
- ARC-28 event filtering
- Custom filter functions

#### Data Transformation
- Algod block format → Indexer transaction format
- Automatic balance change extraction
- Inner transaction handling (recursive)
- ARC-28 event parsing from logs
- ABI argument decoding

#### Subscription Features
- Single poll (`poll_once`)
- Continuous polling (`start`/`stop`)
- Configurable polling frequency
- Wait-for-block optimization
- Watermark persistence (pluggable)
- Error recovery
- Graceful shutdown

#### Event System
- Transaction events (per-transaction)
- Batch events (all matching transactions)
- Poll lifecycle events (before/after)
- Error events
- Thread-safe event emission
- Async event support

#### Sync Strategies
- **Catchup with indexer** - Use indexer for large gaps, algod for small gaps
- **Sync oldest** - Always sync from oldest unsynced round
- **Sync oldest start now** - Skip history, start from current round
- **Skip sync newest** - Jump to latest round
- **Fail** - Fail if behind

### Examples
- Data History Museum asset monitoring
- USDC transfer tracking
- Simple payment tracker
- ARC-28 event listener

### Documentation
- Comprehensive README with examples
- API reference
- Configuration guide
- Examples directory
- Phase completion documents

## [0.1.0] - 2025-10-29

### Added
- Initial development release
- Core functionality complete
- Production-ready implementation

