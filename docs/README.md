# AlgoKit Subscriber Documentation

Complete documentation for the AlgoKit Subscriber Ruby gem.

## 📚 Documentation Index

### Getting Started

- **[Getting Started Guide](GETTING_STARTED.md)** - Installation, basic concepts, and your first subscriber
  - Installation & setup
  - Basic concepts
  - Your first subscriber
  - Common patterns
  - Testing your subscriber
  - Troubleshooting

### Core Documentation

- **[Quick Reference](QUICK_REFERENCE.md)** - Cheat sheet for common tasks
  - Installation & setup snippets
  - Common filter examples
  - Event handler patterns
  - Configuration options
  - Transaction data access
  - Common patterns

- **[API Reference](API_REFERENCE.md)** - Complete API documentation
  - AlgorandSubscriber class
  - SubscriptionConfig options
  - Transaction filters
  - Balance change tracking
  - ARC-28 events
  - Client APIs (AlgodClient, IndexerClient)
  - Models and types
  - Utilities

- **[Advanced Usage Guide](ADVANCED_USAGE.md)** - Advanced patterns and optimization
  - Advanced filtering techniques
  - Balance change tracking strategies
  - ARC-28 event processing
  - Sync strategies comparison
  - Watermark persistence options
  - Performance optimization
  - Error handling patterns
  - Production deployment
  - Monitoring & observability

- **[Architecture & Internals](ARCHITECTURE.md)** - Deep dive into the gem's architecture
  - High-level architecture
  - Core components
  - Data flow
  - Threading model
  - Transaction processing pipeline
  - Sync strategies internals
  - Balance change algorithm
  - ARC-28 event parsing
  - Performance characteristics
  - Design decisions

- **[Testing Guide](TESTING.md)** - Testing guide and coverage details
  - Running tests
  - Test suite overview (255 tests, 83% coverage)
  - Documentation examples tests (66 tests)
  - Core functionality tests
  - Writing tests
  - CI/CD integration

## 📖 Quick Navigation

### I want to...

**Get started quickly**
→ [Getting Started Guide](GETTING_STARTED.md)

**Quick cheat sheet**
→ [Quick Reference](QUICK_REFERENCE.md)

**Understand all configuration options**
→ [API Reference - SubscriptionConfig](API_REFERENCE.md#subscriptionconfig)

**Learn about different sync strategies**
→ [Advanced Usage - Sync Strategies](ADVANCED_USAGE.md#sync-strategies)

**Track balance changes**
→ [Advanced Usage - Balance Change Tracking](ADVANCED_USAGE.md#balance-change-tracking)

**Listen to smart contract events**
→ [Advanced Usage - ARC-28 Events](ADVANCED_USAGE.md#arc-28-event-processing)

**Deploy to production**
→ [Advanced Usage - Production Deployment](ADVANCED_USAGE.md#production-deployment)

**Understand how it works internally**
→ [Architecture & Internals](ARCHITECTURE.md)

**See working examples**
→ [Examples Directory](../examples/)

**Run tests or add new tests**
→ [Testing Guide](TESTING.md)

**Understand transaction filters**
→ [API Reference - Transaction Filters](API_REFERENCE.md#transaction-filters)

**Optimize performance**
→ [Advanced Usage - Performance Optimization](ADVANCED_USAGE.md#performance-optimization)

**Handle errors properly**
→ [Advanced Usage - Error Handling](ADVANCED_USAGE.md#error-handling)

**Set up monitoring**
→ [Advanced Usage - Monitoring & Observability](ADVANCED_USAGE.md#monitoring--observability)

## 🎯 Use Case Guides

### Payment Tracking

1. Read [Getting Started - Your First Subscriber](GETTING_STARTED.md#your-first-subscriber)
2. Review [examples/simple_payment_tracker.rb](../examples/simple_payment_tracker.rb)
3. See [API Reference - TransactionFilter](API_REFERENCE.md#transactionfilter) for filtering options

### Asset Transfer Monitoring

1. Read [Getting Started - Pattern 1: Track Asset Transfers](GETTING_STARTED.md#pattern-1-track-asset-transfers)
2. Review [examples/usdc_monitoring.rb](../examples/usdc_monitoring.rb)
3. See [Advanced Usage - Sync Strategies](ADVANCED_USAGE.md#sync-strategies)

### Smart Contract Event Listening

1. Read [Advanced Usage - ARC-28 Event Processing](ADVANCED_USAGE.md#arc-28-event-processing)
2. Review [examples/arc28_event_listener.rb](../examples/arc28_event_listener.rb)
3. See [API Reference - ARC-28 Events](API_REFERENCE.md#arc-28-events)

### Balance Change Tracking

1. Read [Advanced Usage - Balance Change Tracking](ADVANCED_USAGE.md#balance-change-tracking)
2. See [API Reference - Balance Changes](API_REFERENCE.md#balance-changes)
3. Review [Getting Started - Pattern 4: Track Balance Changes](GETTING_STARTED.md#pattern-4-track-balance-changes)

### Real-Time Monitoring

1. Read [Advanced Usage - Sync Strategies - Strategy 3: Skip Sync Newest](ADVANCED_USAGE.md#strategy-3-skip-sync-newest)
2. Review [examples/usdc_tracking_skip_sync.rb](../examples/usdc_tracking_skip_sync.rb)
3. See [examples/SYNC_BEHAVIORS.md](../examples/SYNC_BEHAVIORS.md)

## 📊 Feature Matrix

| Feature | Getting Started | Quick Reference | API Reference | Advanced Usage | Architecture |
|---------|----------------|-----------------|---------------|----------------|--------------|
| Basic Setup | ✓ | ✓ | | | |
| Configuration Options | | ✓ | ✓ | ✓ | |
| Transaction Filters | ✓ | ✓ | ✓ | ✓ | |
| Balance Changes | ✓ | ✓ | ✓ | ✓ | ✓ |
| ARC-28 Events | | | ✓ | ✓ | ✓ |
| Sync Strategies | | ✓ | ✓ | ✓ | ✓ |
| Watermark Persistence | ✓ | ✓ | ✓ | ✓ | ✓ |
| Error Handling | ✓ | ✓ | ✓ | ✓ | |
| Performance Tips | | | | ✓ | ✓ |
| Production Deployment | | | | ✓ | |
| Monitoring | | | | ✓ | |
| Internals | | | | | ✓ |
| Testing | | | | | ✓ |

## 🔍 Finding Information

### By Topic

- **Configuration:** [API Reference - SubscriptionConfig](API_REFERENCE.md#subscriptionconfig)
- **Filtering:** [API Reference - Transaction Filters](API_REFERENCE.md#transaction-filters)
- **Events:** [API Reference - ARC-28 Events](API_REFERENCE.md#arc-28-events)
- **Clients:** [API Reference - Clients](API_REFERENCE.md#clients)
- **Sync:** [Advanced Usage - Sync Strategies](ADVANCED_USAGE.md#sync-strategies)
- **Performance:** [Advanced Usage - Performance](ADVANCED_USAGE.md#performance-optimization)
- **Production:** [Advanced Usage - Production](ADVANCED_USAGE.md#production-deployment)

### By Difficulty Level

**Beginner**
- [Getting Started Guide](GETTING_STARTED.md)
- [Examples - Simple Payment Tracker](../examples/simple_payment_tracker.rb)
- [API Reference - AlgorandSubscriber](API_REFERENCE.md#algorandsubscriber)

**Intermediate**
- [Advanced Usage - Filtering](ADVANCED_USAGE.md#advanced-filtering)
- [Advanced Usage - Balance Changes](ADVANCED_USAGE.md#balance-change-tracking)
- [Examples - USDC Monitoring](../examples/usdc_monitoring.rb)

**Advanced**
- [Advanced Usage - Production Deployment](ADVANCED_USAGE.md#production-deployment)
- [Architecture & Internals](ARCHITECTURE.md)
- [Advanced Usage - Monitoring](ADVANCED_USAGE.md#monitoring--observability)

## 🎓 Learning Path

### Path 1: Quick Start (30 minutes)

1. Read [Getting Started - Installation](GETTING_STARTED.md#installation)
2. Complete [Getting Started - Your First Subscriber](GETTING_STARTED.md#your-first-subscriber)
3. Run [examples/simple_payment_tracker.rb](../examples/simple_payment_tracker.rb)
4. Experiment with [Getting Started - Common Patterns](GETTING_STARTED.md#common-patterns)

### Path 2: Production Ready (2-3 hours)

1. Complete Path 1 (Quick Start)
2. Read [Advanced Usage - Sync Strategies](ADVANCED_USAGE.md#sync-strategies)
3. Read [Advanced Usage - Watermark Persistence](ADVANCED_USAGE.md#watermark-persistence)
4. Read [Advanced Usage - Error Handling](ADVANCED_USAGE.md#error-handling)
5. Read [Advanced Usage - Production Deployment](ADVANCED_USAGE.md#production-deployment)
6. Review [examples/usdc_monitoring.rb](../examples/usdc_monitoring.rb)

### Path 3: Deep Understanding (4-5 hours)

1. Complete Path 2 (Production Ready)
2. Read [Architecture & Internals](ARCHITECTURE.md) (entire document)
3. Read [Advanced Usage - Performance Optimization](ADVANCED_USAGE.md#performance-optimization)
4. Read [Advanced Usage - Monitoring](ADVANCED_USAGE.md#monitoring--observability)
5. Study the source code starting with [lib/algokit/subscriber/algorand_subscriber.rb](../lib/algokit/subscriber/algorand_subscriber.rb)

### Path 4: Smart Contract Events (1-2 hours)

1. Complete Path 1 (Quick Start)
2. Read [API Reference - ARC-28 Events](API_REFERENCE.md#arc-28-events)
3. Read [Advanced Usage - ARC-28 Event Processing](ADVANCED_USAGE.md#arc-28-event-processing)
4. Review [examples/arc28_event_listener.rb](../examples/arc28_event_listener.rb)
5. Read [Architecture - ARC-28 Event Parsing](ARCHITECTURE.md#arc-28-event-parsing)

## 🔗 External Resources

### Algorand Resources

- [Algorand Developer Portal](https://developer.algorand.org/)
- [Algod REST API Reference](https://developer.algorand.org/docs/rest-apis/algod/)
- [Indexer REST API Reference](https://developer.algorand.org/docs/rest-apis/indexer/)
- [ARC-28 Event Specification](https://github.com/algorandfoundation/ARCs/blob/main/ARCs/arc-0028.md)
- [Public Algorand Nodes](https://algonode.io/)

### Tools & Explorers

- [AlgoExplorer TestNet](https://testnet.algoexplorer.io/)
- [AlgoExplorer MainNet](https://algoexplorer.io/)
- [Pera Explorer](https://explorer.perawallet.app/)

### Related Projects

- [algokit-subscriber-ts](https://github.com/algorandfoundation/algokit-subscriber-ts) - TypeScript version (this gem is a port)
- [AlgoKit](https://github.com/algorandfoundation/algokit-cli) - Algorand development toolkit

## 🤝 Contributing

Found an issue with the documentation?

1. Check [existing issues](https://github.com/loedn/algokit-subscriber-rb/issues)
2. Open a new issue with:
   - Documentation page affected
   - What's unclear or incorrect
   - Suggested improvement

Want to improve the docs?

1. Fork the repository
2. Edit the relevant markdown file in `docs/`
3. Submit a pull request

## 📝 Documentation Standards

This documentation follows these principles:

- **Progressive Disclosure:** Start simple, add complexity gradually
- **Task-Oriented:** Focus on what users want to accomplish
- **Complete Examples:** All code examples are complete and runnable
- **Cross-Referencing:** Link related concepts across documents
- **Search-Friendly:** Use clear headings and keywords

## ❓ Getting Help

If you can't find what you're looking for:

1. **Search the docs** - Use Ctrl+F / Cmd+F on each page
2. **Check examples** - The [examples directory](../examples/) has working code
3. **Read the source** - Code is well-commented and readable
4. **Ask for help** - Open an issue on [GitHub](https://github.com/loedn/algokit-subscriber-rb/issues)

## 📄 License

This documentation is part of the algokit-subscriber gem and is available under the [MIT License](../LICENSE.txt).

---

**Last Updated:** 2025-10-30  
**Gem Version:** 0.1.0  
**Docs Version:** 1.0
