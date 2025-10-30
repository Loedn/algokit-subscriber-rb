# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Documentation Examples" do
  let(:algod_server) { "https://testnet-api.algonode.cloud" }
  let(:indexer_server) { "https://testnet-idx.algonode.cloud" }
  let(:algod) { Algokit::Subscriber::Client::AlgodClient.new(algod_server) }
  let(:indexer) { Algokit::Subscriber::Client::IndexerClient.new(indexer_server) }

  describe "README.md Examples" do
    describe "Quick Start Example" do
      it "creates a subscriber and registers handler" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "payments",
              filter: { type: "pay", min_amount: 1_000_000 } # Payments > 1 ALGO
            }
          ],
          frequency_in_seconds: 1.0
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

        handler_called = false
        subscriber.on("payments") do |transaction|
          handler_called = true
          expect(transaction).to be_a(Hash)
          expect(transaction["tx-type"]).to eq("pay")
        end

        expect(subscriber).to be_a(Algokit::Subscriber::AlgorandSubscriber)
        expect(subscriber.running?).to be false
      end
    end

    describe "Basic Payment Monitoring" do
      it "filters payments by minimum amount" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "large-payments",
              filter: {
                type: "pay",
                min_amount: 10_000_000 # 10 ALGO
              }
            }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)
        expect(subscriber.config.filters.first.name).to eq("large-payments")
        expect(subscriber.config.filters.first.filter.type).to eq("pay")
        expect(subscriber.config.filters.first.filter.min_amount).to eq(10_000_000)
      end
    end

    describe "Asset Transfer Monitoring" do
      it "filters USDC transfers" do
        usdc_asset_id = 10_458_941 # TestNet USDC

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "usdc-transfers",
              filter: {
                type: "axfer",
                asset_id: usdc_asset_id
              }
            }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)
        expect(subscriber.config.filters.first.filter.asset_id).to eq(usdc_asset_id)
      end
    end

    describe "Application Call Monitoring" do
      it "filters application calls by app_id" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "app-calls",
              filter: {
                type: "appl",
                app_id: 123_456
              }
            }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)
        expect(subscriber.config.filters.first.filter.app_id).to eq(123_456)
      end
    end

    describe "Balance Change Tracking" do
      it "tracks balance changes for specific address" do
        treasury = "TREASURY_ADDRESS_HERE"

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "treasury-deposits",
              filter: {
                type: "pay",
                balance_changes: [
                  {
                    address: treasury,
                    min_amount: 1_000_000,
                    roles: ["Receiver"]
                  }
                ]
              }
            }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)
        balance_filter = subscriber.config.filters.first.filter.balance_changes.first
        expect(balance_filter[:address]).to eq(treasury)
        expect(balance_filter[:min_amount]).to eq(1_000_000)
      end
    end

    describe "Batch Processing" do
      it "registers batch handler" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "payments", filter: { type: "pay" } }]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

        batch_handler_called = false
        subscriber.on_batch("payments") do |transactions|
          batch_handler_called = true
          expect(transactions).to be_an(Array)
        end

        expect(subscriber).to be_a(Algokit::Subscriber::AlgorandSubscriber)
      end
    end

    describe "Watermark Persistence - File-based" do
      it "configures file-based watermark persistence" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "payments", filter: { type: "pay" } }],
          watermark_persistence: {
            get: -> { 0 },
            set: ->(_w) { nil }
          }
        )

        expect(config.watermark_persistence).to be_a(Algokit::Subscriber::Types::WatermarkPersistence)
        expect(config.watermark_persistence.get_watermark).to eq(0)
      end
    end

    describe "Lifecycle Events" do
      it "registers before_poll handler" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "payments", filter: { type: "pay" } }]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

        before_poll_called = false
        subscriber.on_before_poll do |watermark, current_round|
          before_poll_called = true
          expect(watermark).to be_a(Integer)
          expect(current_round).to be_a(Integer)
        end

        expect(subscriber).to be_a(Algokit::Subscriber::AlgorandSubscriber)
      end

      it "registers poll handler" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "payments", filter: { type: "pay" } }]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

        poll_handler_called = false
        subscriber.on_poll do |result|
          poll_handler_called = true
          expect(result).to be_a(Algokit::Subscriber::Types::SubscriptionResult)
        end

        expect(subscriber).to be_a(Algokit::Subscriber::AlgorandSubscriber)
      end

      it "registers error handler" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "payments", filter: { type: "pay" } }]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

        error_handler_called = false
        subscriber.on_error do |error|
          error_handler_called = true
          expect(error).to be_a(StandardError)
        end

        expect(subscriber).to be_a(Algokit::Subscriber::AlgorandSubscriber)
      end
    end
  end

  describe "GETTING_STARTED.md Examples" do
    describe "Step 1: Set Up Clients" do
      it "creates algod client" do
        client = Algokit::Subscriber::Client::AlgodClient.new("https://testnet-api.algonode.cloud")
        expect(client).to be_a(Algokit::Subscriber::Client::AlgodClient)
      end

      it "creates indexer client" do
        client = Algokit::Subscriber::Client::IndexerClient.new("https://testnet-idx.algonode.cloud")
        expect(client).to be_a(Algokit::Subscriber::Client::IndexerClient)
      end

      it "creates private node client with token" do
        client = Algokit::Subscriber::Client::AlgodClient.new(
          "http://localhost:4001",
          token: "test-token-here"
        )
        expect(client).to be_a(Algokit::Subscriber::Client::AlgodClient)
      end
    end

    describe "Step 2: Create a Configuration" do
      it "creates configuration with filters" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "payments",
              filter: {
                type: "pay",
                min_amount: 1_000_000
              }
            }
          ],
          frequency_in_seconds: 1.0
        )

        expect(config.filters.length).to eq(1)
        expect(config.filters.first.name).to eq("payments")
        expect(config.frequency_in_seconds).to eq(1.0)
      end
    end

    describe "Pattern 1: Track Asset Transfers" do
      it "monitors USDC transfers" do
        usdc_asset_id = 10_458_941

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "usdc-transfers",
              filter: {
                type: "axfer",
                asset_id: usdc_asset_id
              }
            }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)
        expect(subscriber.config.filters.first.filter.asset_id).to eq(usdc_asset_id)
      end
    end

    describe "Pattern 2: Monitor Specific Address" do
      it "tracks treasury incoming and outgoing" do
        treasury = "YOUR_ADDRESS_HERE"

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "treasury-incoming",
              filter: {
                type: "pay",
                receiver: treasury
              }
            },
            {
              name: "treasury-outgoing",
              filter: {
                type: "pay",
                sender: treasury
              }
            }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)
        expect(subscriber.config.filters.length).to eq(2)
      end
    end

    describe "Pattern 3: Batch Processing" do
      it "processes transactions in batches" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "payments", filter: { type: "pay" } }]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

        subscriber.on_batch("payments") do |transactions|
          total = transactions.sum { |t| t.dig("payment-transaction", "amount") || 0 }
          expect(total).to be >= 0
        end
      end
    end

    describe "Pattern 4: Track Balance Changes" do
      it "tracks balance changes with filters" do
        treasury = "TREASURY_ADDRESS"

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "treasury-changes",
              filter: {
                balance_changes: [
                  {
                    address: treasury,
                    min_absolute_amount: 1_000_000
                  }
                ]
              }
            }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)
        expect(subscriber.config.filters.first.name).to eq("treasury-changes")
      end
    end

    describe "Pattern 5: Application Monitoring" do
      it "monitors smart contract calls" do
        app_id = 123_456

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "app-calls",
              filter: {
                type: "appl",
                app_id: app_id
              }
            }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)
        expect(subscriber.config.filters.first.filter.app_id).to eq(app_id)
      end
    end
  end

  describe "QUICK_REFERENCE.md Examples" do
    describe "Common Filters" do
      it "creates payment filter" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(type: "pay")
        expect(filter.type).to eq("pay")
      end

      it "creates payment filter with min amount" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(
          type: "pay",
          min_amount: 1_000_000
        )
        expect(filter.min_amount).to eq(1_000_000)
      end

      it "creates payment filter with receiver" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(
          type: "pay",
          receiver: "ADDRESS"
        )
        expect(filter.receiver).to eq("ADDRESS")
      end

      it "creates payment filter with amount range" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(
          type: "pay",
          min_amount: 1_000_000,
          max_amount: 10_000_000
        )
        expect(filter.min_amount).to eq(1_000_000)
        expect(filter.max_amount).to eq(10_000_000)
      end
    end

    describe "Asset Filters" do
      it "creates asset transfer filter" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(type: "axfer")
        expect(filter.type).to eq("axfer")
      end

      it "creates specific asset transfer filter" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(
          type: "axfer",
          asset_id: 10_458_941
        )
        expect(filter.asset_id).to eq(10_458_941)
      end

      it "creates asset creation filter" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(
          type: "acfg",
          asset_create: true
        )
        expect(filter.asset_create).to be true
      end
    end

    describe "Application Filters" do
      it "creates app call filter" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(type: "appl")
        expect(filter.type).to eq("appl")
      end

      it "creates specific app call filter" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(
          type: "appl",
          app_id: 123_456
        )
        expect(filter.app_id).to eq(123_456)
      end

      it "creates app creation filter" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(
          type: "appl",
          app_create: true
        )
        expect(filter.app_create).to be true
      end

      it "creates method signature filter" do
        filter = Algokit::Subscriber::Types::TransactionFilter.new(
          type: "appl",
          app_id: 123_456,
          method_signature: "swap(uint64,uint64)uint64"
        )
        expect(filter.method_signature).to eq("swap(uint64,uint64)uint64")
      end
    end

    describe "Balance Change Filters" do
      it "tracks address balance changes" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "balance-tracker",
              filter: {
                balance_changes: [
                  { address: "ADDRESS", min_absolute_amount: 1_000_000 }
                ]
              }
            }
          ]
        )

        expect(config.filters.first.filter.balance_changes.first[:min_absolute_amount]).to eq(1_000_000)
      end

      it "tracks specific asset" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "usdc-tracker",
              filter: {
                balance_changes: [
                  { address: "ADDRESS", asset_id: 10_458_941, min_amount: 1_000_000 }
                ]
              }
            }
          ]
        )

        filter = config.filters.first.filter.balance_changes.first
        expect(filter[:asset_id]).to eq(10_458_941)
      end

      it "tracks only deposits" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "deposits",
              filter: {
                balance_changes: [
                  { address: "ADDRESS", roles: ["Receiver"], min_amount: 1 }
                ]
              }
            }
          ]
        )

        filter = config.filters.first.filter.balance_changes.first
        expect(filter[:roles]).to eq(["Receiver"])
      end
    end

    describe "Sync Behaviors" do
      it "uses catchup with indexer" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::CATCHUP_WITH_INDEXER
        )

        expect(config.sync_behaviour).to eq("catchup-with-indexer")
      end

      it "uses skip sync newest" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST
        )

        expect(config.sync_behaviour).to eq("skip-sync-newest")
      end

      it "uses sync oldest start now" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST_START_NOW
        )

        expect(config.sync_behaviour).to eq("sync-oldest-start-now")
      end

      it "uses sync oldest" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST
        )

        expect(config.sync_behaviour).to eq("sync-oldest")
      end

      it "uses fail" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::FAIL
        )

        expect(config.sync_behaviour).to eq("fail")
      end
    end

    describe "Watermark Persistence" do
      it "configures file-based persistence" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          watermark_persistence: {
            get: -> { 12_345 },
            set: ->(_w) { nil }
          }
        )

        expect(config.watermark_persistence.get_watermark).to eq(12_345)
      end

      it "configures redis persistence simulation" do
        redis_mock = { "watermark" => "54321" }

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          watermark_persistence: {
            get: -> { redis_mock["watermark"].to_i },
            set: ->(w) { redis_mock["watermark"] = w.to_s }
          }
        )

        expect(config.watermark_persistence.get_watermark).to eq(54_321)
        config.watermark_persistence.set_watermark(99_999)
        expect(redis_mock["watermark"]).to eq("99999")
      end
    end

    describe "Configuration Options" do
      it "configures all options" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          arc28_events: [],
          max_rounds_to_sync: 50,
          max_indexer_rounds_to_sync: 2000,
          sync_behaviour: "skip-sync-newest",
          frequency_in_seconds: 2.0,
          wait_for_block_when_at_tip: false,
          watermark_persistence: nil
        )

        expect(config.max_rounds_to_sync).to eq(50)
        expect(config.max_indexer_rounds_to_sync).to eq(2000)
        expect(config.frequency_in_seconds).to eq(2.0)
        expect(config.wait_for_block_when_at_tip).to be false
      end
    end
  end

  describe "ADVANCED_USAGE.md Examples" do
    describe "Combining Multiple Criteria" do
      it "creates complex filter" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "large-usdc-to-treasury",
              filter: {
                type: "axfer",
                asset_id: 10_458_941,
                receiver: "TREASURY_ADDRESS",
                min_amount: 100_000_000
              }
            }
          ]
        )

        filter = config.filters.first.filter
        expect(filter.type).to eq("axfer")
        expect(filter.asset_id).to eq(10_458_941)
        expect(filter.receiver).to eq("TREASURY_ADDRESS")
        expect(filter.min_amount).to eq(100_000_000)
      end
    end

    describe "Custom Filter Functions" do
      it "creates custom filter" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "suspicious-payments",
              filter: {
                type: "pay",
                custom_filter: lambda do |txn|
                  amount = txn.dig("payment-transaction", "amount")
                  amount == 1_234_000
                end
              }
            }
          ]
        )

        filter = config.filters.first.filter
        expect(filter.custom_filter).to be_a(Proc)

        # Test the custom filter
        matching_txn = { "payment-transaction" => { "amount" => 1_234_000 } }
        non_matching_txn = { "payment-transaction" => { "amount" => 5_000_000 } }

        expect(filter.custom_filter.call(matching_txn)).to be true
        expect(filter.custom_filter.call(non_matching_txn)).to be false
      end
    end

    describe "Multiple Filters for Same Transaction Type" do
      it "creates multiple payment filters" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "small-payments",
              filter: {
                type: "pay",
                min_amount: 1_000_000,
                max_amount: 10_000_000
              }
            },
            {
              name: "large-payments",
              filter: {
                type: "pay",
                min_amount: 10_000_000
              }
            },
            {
              name: "vip-payments",
              filter: {
                type: "pay",
                sender: "VIP_ADDRESS",
                min_amount: 1
              }
            }
          ]
        )

        expect(config.filters.length).to eq(3)
        expect(config.filters.map(&:name)).to eq(["small-payments", "large-payments", "vip-payments"])
      end
    end

    describe "ARC-28 Event Processing" do
      it "defines event schema" do
        dex_events = Algokit::Subscriber::Types::Arc28EventGroup.new(
          group_name: "DEX",
          events: [
            {
              name: "Swap",
              args: [
                { name: "trader", type: "address" },
                { name: "tokenIn", type: "uint64" },
                { name: "amountIn", type: "uint64" },
                { name: "tokenOut", type: "uint64" },
                { name: "amountOut", type: "uint64" },
                { name: "timestamp", type: "uint64" }
              ]
            }
          ]
        )

        expect(dex_events.group_name).to eq("DEX")
        expect(dex_events.events.first.name).to eq("Swap")
        expect(dex_events.events.first.args.length).to eq(6)
      end

      it "configures event filters" do
        dex_events = Algokit::Subscriber::Types::Arc28EventGroup.new(
          group_name: "DEX",
          events: [
            {
              name: "Swap",
              args: [
                { name: "trader", type: "address" },
                { name: "amountIn", type: "uint64" },
                { name: "amountOut", type: "uint64" }
              ]
            }
          ]
        )

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "dex-swaps",
              filter: {
                type: "appl",
                app_id: 789,
                arc28_events: [
                  { group_name: "DEX", event_name: "Swap" }
                ]
              }
            }
          ],
          arc28_events: [dex_events]
        )

        expect(config.arc28_events.length).to eq(1)
        expect(config.filters.first.filter.arc28_events.first[:group_name]).to eq("DEX")
      end
    end

    describe "Sync Strategy Examples" do
      it "configures catchup with indexer" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::CATCHUP_WITH_INDEXER
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)
        expect(subscriber.config.sync_behaviour).to eq("catchup-with-indexer")
      end

      it "configures sync oldest start now with persistence" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SYNC_OLDEST_START_NOW,
          watermark_persistence: {
            get: -> { 0 },
            set: ->(_w) { nil }
          }
        )

        expect(config.sync_behaviour).to eq("sync-oldest-start-now")
        expect(config.watermark_persistence).not_to be_nil
      end

      it "configures skip sync newest for real-time" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST,
          wait_for_block_when_at_tip: true,
          frequency_in_seconds: 0.5
        )

        expect(config.sync_behaviour).to eq("skip-sync-newest")
        expect(config.wait_for_block_when_at_tip).to be true
        expect(config.frequency_in_seconds).to eq(0.5)
      end
    end

    describe "Performance Optimization" do
      it "optimizes polling frequency" do
        # High-frequency config
        high_freq_config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          frequency_in_seconds: 0.5,
          wait_for_block_when_at_tip: true
        )

        expect(high_freq_config.frequency_in_seconds).to eq(0.5)

        # Low-frequency config
        low_freq_config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          frequency_in_seconds: 5.0,
          wait_for_block_when_at_tip: false
        )

        expect(low_freq_config.frequency_in_seconds).to eq(5.0)
      end

      it "optimizes batch size" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          max_rounds_to_sync: 30,
          max_indexer_rounds_to_sync: 2000
        )

        expect(config.max_rounds_to_sync).to eq(30)
        expect(config.max_indexer_rounds_to_sync).to eq(2000)
      end
    end
  end

  describe "API_REFERENCE.md Examples" do
    describe "AlgorandSubscriber Constructor" do
      it "creates subscriber with config and clients" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "payments", filter: { type: "pay" } }]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod, indexer)

        expect(subscriber).to be_a(Algokit::Subscriber::AlgorandSubscriber)
        expect(subscriber.config).to eq(config)
        expect(subscriber.algod).to eq(algod)
        expect(subscriber.indexer).to eq(indexer)
      end
    end

    describe "Event Handler Methods" do
      let(:config) do
        Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }]
        )
      end
      let(:subscriber) { Algokit::Subscriber::AlgorandSubscriber.new(config, algod) }

      it "registers on handler" do
        expect do
          subscriber.on("test") { |_txn| nil }
        end.not_to raise_error
      end

      it "registers on_batch handler" do
        expect do
          subscriber.on_batch("test") { |_txns| nil }
        end.not_to raise_error
      end

      it "registers on_before_poll handler" do
        expect do
          subscriber.on_before_poll { |_w, _r| nil }
        end.not_to raise_error
      end

      it "registers on_poll handler" do
        expect do
          subscriber.on_poll { |_result| nil }
        end.not_to raise_error
      end

      it "registers on_error handler" do
        expect do
          subscriber.on_error { |_error| nil }
        end.not_to raise_error
      end
    end

    describe "BalanceChange" do
      it "creates balance change object" do
        balance_change = Algokit::Subscriber::Types::BalanceChange.new(
          address: "ADDRESS",
          asset_id: 0,
          amount: 1_000_000,
          roles: ["Receiver"]
        )

        expect(balance_change.address).to eq("ADDRESS")
        expect(balance_change.asset_id).to eq(0)
        expect(balance_change.amount).to eq(1_000_000)
        expect(balance_change.roles).to eq(["Receiver"])
        expect(balance_change.algo_change?).to be true
        expect(balance_change.asset_change?).to be false
      end

      it "converts balance change to hash" do
        balance_change = Algokit::Subscriber::Types::BalanceChange.new(
          address: "ADDRESS",
          asset_id: 10_458_941,
          amount: 5_000_000,
          roles: ["Sender"]
        )

        hash = balance_change.to_h
        expect(hash[:address]).to eq("ADDRESS")
        expect(hash[:asset_id]).to eq(10_458_941)
        expect(hash[:amount]).to eq(5_000_000)
        expect(hash[:roles]).to eq(["Sender"])
      end
    end
  end

  describe "Configuration Validation" do
    it "validates valid configuration" do
      config = Algokit::Subscriber::Types::SubscriptionConfig.new(
        filters: [{ name: "test", filter: { type: "pay" } }],
        max_rounds_to_sync: 100,
        frequency_in_seconds: 1.0
      )

      expect { config.validate! }.not_to raise_error
    end

    it "raises error for invalid sync behaviour" do
      expect do
        Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: "invalid-behaviour"
        ).validate!
      end.to raise_error(Algokit::Subscriber::ConfigurationError)
    end

    it "raises error for non-positive max_rounds_to_sync" do
      expect do
        Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          max_rounds_to_sync: 0
        ).validate!
      end.to raise_error(Algokit::Subscriber::ConfigurationError)
    end

    it "raises error for non-positive frequency" do
      expect do
        Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          frequency_in_seconds: 0
        ).validate!
      end.to raise_error(Algokit::Subscriber::ConfigurationError)
    end
  end

  describe "Real-world Patterns" do
    describe "Track Specific Address Activity" do
      it "creates filters for incoming and outgoing" do
        wallet = "YOUR_ADDRESS"

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            { name: "incoming", filter: { type: "pay", receiver: wallet } },
            { name: "outgoing", filter: { type: "pay", sender: wallet } }
          ]
        )

        subscriber = Algokit::Subscriber::AlgorandSubscriber.new(config, algod)

        subscriber.on("incoming") { |_txn| nil }
        subscriber.on("outgoing") { |_txn| nil }

        expect(config.filters.length).to eq(2)
      end
    end

    describe "Monitor Multiple Assets" do
      it "creates filters for multiple assets" do
        usdc = 10_458_941
        token = 123_456

        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            { name: "usdc", filter: { type: "axfer", asset_id: usdc } },
            { name: "token", filter: { type: "axfer", asset_id: token } }
          ]
        )

        expect(config.filters.length).to eq(2)
        expect(config.filters.map { |f| f.filter.asset_id }).to eq([usdc, token])
      end
    end

    describe "Real-Time Monitoring" do
      it "configures for low latency" do
        config = Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [{ name: "test", filter: { type: "pay" } }],
          sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::SKIP_SYNC_NEWEST,
          wait_for_block_when_at_tip: true,
          frequency_in_seconds: 0.5
        )

        expect(config.sync_behaviour).to eq("skip-sync-newest")
        expect(config.wait_for_block_when_at_tip).to be true
        expect(config.frequency_in_seconds).to eq(0.5)
      end
    end
  end
end
