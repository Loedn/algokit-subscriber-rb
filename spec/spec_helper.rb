# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/fixtures/"
end

require "bundler/setup"
require "algokit/subscriber"
require "webmock/rspec"
require "vcr"

# Disable real HTTP connections in tests
WebMock.disable_net_connect!(allow_localhost: false)

# Configure VCR for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method uri body]
  }

  # Allow HTTP connections when no cassette is in use (for WebMock stubs)
  config.allow_http_connections_when_no_cassette = true

  # Filter sensitive data
  config.filter_sensitive_data("<ALGOD_TOKEN>") { ENV.fetch("ALGOD_TOKEN", nil) }
  config.filter_sensitive_data("<INDEXER_TOKEN>") { ENV.fetch("INDEXER_TOKEN", nil) }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Allow focusing on specific tests
  config.filter_run_when_matching :focus
end
