# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::AlgorandSubscriber do
  let(:algod) { instance_double(Algokit::Subscriber::Client::AlgodClient) }
  let(:indexer) { instance_double(Algokit::Subscriber::Client::IndexerClient) }
  let(:watermark_store) { { value: 1000 } }

  let(:config) do
    Algokit::Subscriber::Types::SubscriptionConfig.new(
      filters: [
        {
          name: "payments",
          filter: { type: "pay", min_amount: 1000 }
        }
      ],
      max_rounds_to_sync: 5,
      frequency_in_seconds: 0.1,
      wait_for_block_when_at_tip: false,
      watermark_persistence: {
        get: -> { watermark_store[:value] },
        set: ->(w) { watermark_store[:value] = w }
      }
    )
  end

  let(:subscriber) { described_class.new(config, algod, indexer) }

  let(:status_response) do
    { "last-round" => 1005, "time-since-last-round" => 1_000_000 }
  end

  let(:block_data) do
    {
      "block" => {
        "rnd" => 1001,
        "ts" => 1_700_000_000,
        "gen" => "testnet-v1.0",
        "gh" => "SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI=",
        "txns" => [
          {
            "txn" => {
              "type" => "pay",
              "snd" => "SENDER",
              "rcv" => "RECEIVER",
              "amt" => 5000,
              "fee" => 1000,
              "fv" => 1000,
              "lv" => 1100,
              "tx-id" => "TXN123"
            }
          }
        ]
      }
    }
  end

  before do
    allow(algod).to receive(:status).and_return(status_response)
    (1001..1005).each do |round|
      block_with_round = block_data.merge("block" => block_data["block"].merge("rnd" => round))
      allow(algod).to receive(:block).with(round).and_return(block_with_round)
    end
  end

  describe "#initialize" do
    it "creates a subscriber with config" do
      expect(subscriber.config).to eq(config)
      expect(subscriber.algod).to eq(algod)
      expect(subscriber.indexer).to eq(indexer)
    end

    it "initializes watermark from persistence" do
      expect(subscriber.watermark).to eq(1000)
    end

    it "initializes watermark to 0 without persistence" do
      config_no_persist = Algokit::Subscriber::Types::SubscriptionConfig.new(
        filters: [{ name: "test", filter: { type: "pay" } }]
      )
      sub = described_class.new(config_no_persist, algod)
      expect(sub.watermark).to eq(0)
    end
  end

  describe "#on" do
    it "registers a transaction handler" do
      handler = proc { |txn| txn }
      result = subscriber.on("payments", &handler)
      expect(result).to eq(handler)
    end

    it "requires a block" do
      expect { subscriber.on("payments") }.to raise_error(ArgumentError, "Block required")
    end
  end

  describe "#on_batch" do
    it "registers a batch handler" do
      handler = proc { |txns| txns }
      result = subscriber.on_batch("payments", &handler)
      expect(result).to eq(handler)
    end

    it "requires a block" do
      expect { subscriber.on_batch("payments") }.to raise_error(ArgumentError, "Block required")
    end
  end

  describe "#on_before_poll" do
    it "registers a before_poll handler" do
      handler = proc { |wm, cr| [wm, cr] }
      result = subscriber.on_before_poll(&handler)
      expect(result).to eq(handler)
    end
  end

  describe "#on_poll" do
    it "registers a poll handler" do
      handler = proc { |result| result }
      result = subscriber.on_poll(&handler)
      expect(result).to eq(handler)
    end
  end

  describe "#on_error" do
    it "registers an error handler" do
      handler = proc { |error| error }
      result = subscriber.on_error(&handler)
      expect(result).to eq(handler)
    end
  end

  describe "#poll_once" do
    it "polls for transactions and updates watermark" do
      result = subscriber.poll_once

      expect(result).to be_a(Algokit::Subscriber::Types::SubscriptionResult)
      expect(result.starting_watermark).to eq(1000)
      expect(result.new_watermark).to eq(1005)
      expect(result.synced_round_range.length).to eq(5)
      expect(subscriber.watermark).to eq(1005)
      expect(watermark_store[:value]).to eq(1005)
    end

    it "emits before_poll event" do
      before_poll_called = false
      subscriber.on_before_poll { |_wm, _cr| before_poll_called = true }

      subscriber.poll_once
      expect(before_poll_called).to be true
    end

    it "emits poll event with result" do
      poll_result = nil
      subscriber.on_poll { |result| poll_result = result }

      subscriber.poll_once
      expect(poll_result).to be_a(Algokit::Subscriber::Types::SubscriptionResult)
    end

    it "emits transaction events for matched transactions" do
      transactions = []
      subscriber.on("payments") { |txn| transactions << txn }

      subscriber.poll_once
      expect(transactions.length).to eq(5)
      expect(transactions.first["tx-type"]).to eq("pay")
    end

    it "emits batch events for matched transactions" do
      batches = []
      subscriber.on_batch("payments") { |txns| batches << txns }

      subscriber.poll_once
      expect(batches.length).to eq(1)
      expect(batches.first.length).to eq(5)
    end

    it "handles errors and emits error event" do
      allow(algod).to receive(:status).and_raise(StandardError, "Network error")

      error_emitted = nil
      subscriber.on_error { |e| error_emitted = e }

      expect { subscriber.poll_once }.to raise_error(StandardError, "Network error")
      expect(error_emitted).to be_a(StandardError)
      expect(error_emitted.message).to eq("Network error")
    end
  end

  describe "#running?" do
    it "returns false initially" do
      expect(subscriber.running?).to be false
    end
  end

  describe "#start and #stop" do
    it "starts and stops the subscriber" do
      expect(subscriber.running?).to be false

      subscriber.stop

      expect(subscriber.running?).to be false
    end
  end

  describe "integration with multiple filters" do
    let(:multi_config) do
      Algokit::Subscriber::Types::SubscriptionConfig.new(
        filters: [
          { name: "payments", filter: { type: "pay" } },
          { name: "large-payments", filter: { type: "pay", min_amount: 10_000 } }
        ],
        watermark_persistence: {
          get: -> { 1000 },
          set: ->(w) {}
        }
      )
    end

    let(:multi_subscriber) { described_class.new(multi_config, algod) }

    it "emits events for each filter" do
      payments = []
      large_payments = []

      multi_subscriber.on("payments") { |txn| payments << txn }
      multi_subscriber.on("large-payments") { |txn| large_payments << txn }

      multi_subscriber.poll_once

      expect(payments.length).to eq(5)
      expect(large_payments.length).to eq(0)
    end
  end
end
