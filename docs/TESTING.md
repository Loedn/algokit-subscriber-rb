# Testing

Testing guide for AlgoKit Subscriber, including how to run tests and details about test coverage.

## Test Suite

The gem has comprehensive test coverage with **255 tests** including:

- **66 documentation examples tests** - All code examples from documentation are tested
- **189 core functionality tests** - Unit and integration tests for all components

### Coverage Stats

- **Total Lines:** 1,076
- **Covered Lines:** 894
- **Coverage:** 83.09%
- **Test Files:** 13

## Running Tests

### Run All Tests

```bash
bundle exec rspec
```

### Run Specific Test File

```bash
# Documentation examples
bundle exec rspec spec/documentation_examples_spec.rb

# Core functionality
bundle exec rspec spec/algorand_subscriber_spec.rb
bundle exec rspec spec/subscriptions_spec.rb
bundle exec rspec spec/transform_spec.rb

# Clients
bundle exec rspec spec/client/algod_client_spec.rb
bundle exec rspec spec/client/indexer_client_spec.rb

# Types
bundle exec rspec spec/types/transaction_filter_spec.rb
bundle exec rspec spec/types/balance_change_spec.rb
```

### Run with Documentation Format

```bash
bundle exec rspec --format documentation
```

### Run with Coverage Report

```bash
COVERAGE=true bundle exec rspec
```

Coverage report will be generated in `coverage/` directory.

### Run Specific Examples

```bash
# Run only README examples
bundle exec rspec spec/documentation_examples_spec.rb -e "README.md Examples"

# Run only Getting Started examples
bundle exec rspec spec/documentation_examples_spec.rb -e "GETTING_STARTED.md Examples"

# Run only Quick Reference examples
bundle exec rspec spec/documentation_examples_spec.rb -e "QUICK_REFERENCE.md Examples"

# Run only Advanced Usage examples
bundle exec rspec spec/documentation_examples_spec.rb -e "ADVANCED_USAGE.md Examples"

# Run only API Reference examples
bundle exec rspec spec/documentation_examples_spec.rb -e "API_REFERENCE.md Examples"
```

## Documentation Examples Test Suite

All code examples from the documentation are tested to ensure they work correctly.

### What's Tested

#### README.md Examples (11 tests)
- Quick Start Example
- Basic Payment Monitoring
- Asset Transfer Monitoring
- Application Call Monitoring
- Balance Change Tracking
- Batch Processing
- Watermark Persistence
- Lifecycle Events (before_poll, poll, error)

#### GETTING_STARTED.md Examples (9 tests)
- Client setup (algod, indexer, private nodes)
- Configuration creation
- Pattern 1: Track Asset Transfers
- Pattern 2: Monitor Specific Address
- Pattern 3: Batch Processing
- Pattern 4: Track Balance Changes
- Pattern 5: Application Monitoring

#### QUICK_REFERENCE.md Examples (22 tests)
- Common Filters (4 tests)
  - Payment filters with various options
- Asset Filters (3 tests)
  - Asset transfers, creation
- Application Filters (4 tests)
  - App calls, creation, method signatures
- Balance Change Filters (3 tests)
  - Address tracking, specific assets, role filtering
- Sync Behaviors (5 tests)
  - All 5 sync strategies
- Watermark Persistence (2 tests)
  - File-based, Redis simulation
- Configuration Options (1 test)

#### ADVANCED_USAGE.md Examples (15 tests)
- Combining Multiple Criteria
- Custom Filter Functions
- Multiple Filters for Same Type
- ARC-28 Event Processing (2 tests)
- Sync Strategy Examples (3 tests)
- Performance Optimization (2 tests)
- And more advanced patterns

#### API_REFERENCE.md Examples (7 tests)
- AlgorandSubscriber Constructor
- Event Handler Methods (5 tests)
- BalanceChange (2 tests)

#### Additional Tests (2 tests)
- Configuration Validation
- Real-world Patterns

### Test Structure

Each documentation example test:

1. **Creates the exact configuration from documentation**
2. **Verifies it works correctly**
3. **Tests expected behavior**
4. **Ensures type correctness**

Example:

```ruby
describe "Quick Start Example" do
  it "creates a subscriber and registers handler" do
    # Exact code from README.md
    config = Algokit::Subscriber::Types::SubscriptionConfig.new(
      filters: [
        {
          name: "payments",
          filter: { type: "pay", min_amount: 1_000_000 }
        }
      ],
      frequency_in_seconds: 1.0
    )

    subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

    subscriber.on("payments") do |transaction|
      expect(transaction).to be_a(Hash)
      expect(transaction["tx-type"]).to eq("pay")
    end

    # Verify it was created correctly
    expect(subscriber).to be_a(Algokit::Subscriber::AlgorandSubscriber)
    expect(subscriber.running?).to be false
  end
end
```

## Core Functionality Tests

### AlgorandSubscriber (238 lines)
Tests for the main subscriber class:
- Initialization
- Event registration
- Poll lifecycle
- Error handling
- Watermark management
- Start/stop functionality

### Subscriptions (409 lines)
Tests for subscription logic:
- Different sync strategies
- Transaction filtering
- Algod vs indexer paths
- Balance change calculation
- ARC-28 event parsing

### Transform (285 lines)
Tests for data transformation:
- Block to transaction conversion
- Balance change extraction
- ARC-28 event parsing
- Format normalization

### Clients
Tests for API clients:
- **AlgodClient** - HTTP requests, retries, wait-for-block
- **IndexerClient** - Transaction search, pagination, health checks

### Types
Tests for type definitions:
- **TransactionFilter** - All filter types and matching logic
- **BalanceChange** - Balance calculation and role tracking

### Models
Tests for data models:
- **Status** - Node status parsing
- **Block** - Block data structure
- **Transaction** - Transaction parsing

### Utilities
Tests for utility functions:
- Base64 encoding/decoding
- Address encoding
- Helper functions

## Test Helpers

### WebMock
HTTP requests are mocked using WebMock to avoid real network calls during tests.

### VCR
API interactions can be recorded and replayed using VCR cassettes:

```ruby
RSpec.describe "My Test", :vcr do
  it "makes API call" do
    # Interactions are recorded to fixtures/vcr_cassettes/
  end
end
```

### Fixtures
Test fixtures are stored in `fixtures/` directory:
- VCR cassettes for HTTP interactions
- Sample transaction data
- Test blocks and responses

## Writing Tests

### Test Structure

```ruby
RSpec.describe "MyFeature" do
  describe "specific functionality" do
    it "does something specific" do
      # Arrange
      config = create_config
      
      # Act
      result = perform_action
      
      # Assert
      expect(result).to be_something
    end
  end
end
```

### Testing Documentation Examples

When adding new documentation examples:

1. **Add test to `spec/documentation_examples_spec.rb`**
2. **Use exact code from documentation**
3. **Add assertions to verify behavior**
4. **Run tests to ensure they pass**

Example:

```ruby
describe "NEW_DOC.md Examples" do
  describe "New Feature" do
    it "demonstrates new feature" do
      # Copy exact code from documentation
      config = Algokit::Subscriber::Types::SubscriptionConfig.new(
        # ...
      )
      
      # Add assertions
      expect(config).to be_valid
    end
  end
end
```

### Best Practices

1. **Test documentation examples** - Ensures docs stay accurate
2. **Use descriptive test names** - Makes failures easy to understand
3. **Test edge cases** - Not just happy paths
4. **Mock external dependencies** - Use WebMock for HTTP
5. **Keep tests fast** - Avoid real network calls
6. **Test error cases** - Ensure proper error handling

## Continuous Integration

Tests run automatically on:
- Every commit
- Every pull request
- Before merging

### CI Configuration

Tests must pass with:
- ✓ 0 failures
- ✓ >80% code coverage
- ✓ RuboCop passing
- ✓ All documentation examples working

## Test Coverage Details

### High Coverage Areas (>90%)
- Transaction filtering
- Balance change calculation
- Event emission
- Type definitions

### Medium Coverage Areas (70-90%)
- HTTP clients
- Sync strategies
- Data transformation

### Areas for Improvement (<70%)
- Some error edge cases
- Integration scenarios with real networks (intentionally not covered)

## Debugging Tests

### Run Failed Tests Only

```bash
bundle exec rspec --only-failures
```

### Run Next Failure

```bash
bundle exec rspec --next-failure
```

### Debug Output

```ruby
it "debugs something" do
  puts "Debug: #{variable.inspect}"
  binding.pry  # If pry is installed
  expect(something).to be_true
end
```

### Verbose Output

```bash
bundle exec rspec --format documentation --backtrace
```

## Performance Testing

While not part of the automated test suite, you can benchmark performance:

```bash
ruby examples/performance_benchmark.rb
```

This will test:
- Algod sync performance
- Indexer sync performance
- Transaction filtering speed
- Memory usage

## Test Maintenance

### Update Tests When

- Adding new features
- Changing API behavior
- Updating documentation
- Fixing bugs

### Keep Tests Green

If a test fails:

1. **Understand why** - Read the failure message
2. **Fix the code** - If the code is wrong
3. **Update the test** - If the test is wrong
4. **Update docs** - If documentation is outdated

### Regular Maintenance

- Review test coverage monthly
- Update VCR cassettes when APIs change
- Refactor tests to reduce duplication
- Add tests for reported bugs

## Resources

- [RSpec Documentation](https://rspec.info/)
- [WebMock Documentation](https://github.com/bblimke/webmock)
- [VCR Documentation](https://github.com/vcr/vcr)
- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)

## Questions?

If you have questions about testing:

1. Check this documentation
2. Look at existing test files for examples
3. Open an issue on GitHub
4. Ask in your pull request

Happy testing! 🧪
