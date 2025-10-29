# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Types::TransactionFilter do
  describe "#matches?" do
    let(:payment_txn) do
      {
        "tx-type" => "pay",
        "sender" => "SENDER_ADDRESS",
        "txn" => {
          "snd" => "SENDER_ADDRESS",
          "rcv" => "RECEIVER_ADDRESS",
          "amt" => 1000
        },
        "payment-transaction" => {
          "receiver" => "RECEIVER_ADDRESS",
          "amount" => 1000
        }
      }
    end

    context "type filter" do
      it "matches correct type" do
        filter = described_class.new(type: "pay")
        expect(filter.matches?(payment_txn)).to be true
      end

      it "does not match incorrect type" do
        filter = described_class.new(type: "axfer")
        expect(filter.matches?(payment_txn)).to be false
      end
    end

    context "sender filter" do
      it "matches correct sender" do
        filter = described_class.new(sender: "SENDER_ADDRESS")
        expect(filter.matches?(payment_txn)).to be true
      end

      it "does not match incorrect sender" do
        filter = described_class.new(sender: "OTHER_ADDRESS")
        expect(filter.matches?(payment_txn)).to be false
      end
    end

    context "receiver filter" do
      it "matches correct receiver" do
        filter = described_class.new(receiver: "RECEIVER_ADDRESS")
        expect(filter.matches?(payment_txn)).to be true
      end

      it "does not match incorrect receiver" do
        filter = described_class.new(receiver: "OTHER_ADDRESS")
        expect(filter.matches?(payment_txn)).to be false
      end
    end

    context "amount filters" do
      it "matches min_amount" do
        filter = described_class.new(min_amount: 500)
        expect(filter.matches?(payment_txn)).to be true
      end

      it "does not match if amount is too low" do
        filter = described_class.new(min_amount: 2000)
        expect(filter.matches?(payment_txn)).to be false
      end

      it "matches max_amount" do
        filter = described_class.new(max_amount: 2000)
        expect(filter.matches?(payment_txn)).to be true
      end

      it "does not match if amount is too high" do
        filter = described_class.new(max_amount: 500)
        expect(filter.matches?(payment_txn)).to be false
      end

      it "matches amount range" do
        filter = described_class.new(min_amount: 500, max_amount: 2000)
        expect(filter.matches?(payment_txn)).to be true
      end
    end

    context "custom filter" do
      it "applies custom logic" do
        filter = described_class.new(
          custom_filter: ->(txn) { txn.dig("payment-transaction", "amount") > 500 }
        )
        expect(filter.matches?(payment_txn)).to be true
      end

      it "rejects when custom logic returns false" do
        filter = described_class.new(
          custom_filter: ->(txn) { txn.dig("payment-transaction", "amount") > 5000 }
        )
        expect(filter.matches?(payment_txn)).to be false
      end
    end

    context "combined filters" do
      it "matches when all conditions are met" do
        filter = described_class.new(
          type: "pay",
          sender: "SENDER_ADDRESS",
          receiver: "RECEIVER_ADDRESS",
          min_amount: 500
        )
        expect(filter.matches?(payment_txn)).to be true
      end

      it "does not match if any condition fails" do
        filter = described_class.new(
          type: "pay",
          sender: "WRONG_SENDER",
          receiver: "RECEIVER_ADDRESS"
        )
        expect(filter.matches?(payment_txn)).to be false
      end
    end
  end
end

RSpec.describe Algokit::Subscriber::Types::NamedTransactionFilter do
  describe "#initialize" do
    it "creates a named filter with TransactionFilter" do
      filter = Algokit::Subscriber::Types::TransactionFilter.new(type: "pay")
      named = described_class.new(name: "payments", filter: filter)
      expect(named.name).to eq("payments")
      expect(named.filter).to eq(filter)
    end

    it "creates a TransactionFilter from hash" do
      named = described_class.new(name: "payments", filter: { type: "pay" })
      expect(named.name).to eq("payments")
      expect(named.filter).to be_a(Algokit::Subscriber::Types::TransactionFilter)
    end

    it "supports mapper function" do
      mapper = ->(txn) { { id: txn["id"], amount: txn.dig("payment-transaction", "amount") } }
      named = described_class.new(name: "payments", filter: { type: "pay" }, mapper: mapper)
      expect(named.mapper).to eq(mapper)
    end
  end

  describe "#apply" do
    let(:txn) { { "tx-type" => "pay", "id" => "TXN123", "payment-transaction" => { "amount" => 1000 } } }

    it "returns transaction if filter matches" do
      named = described_class.new(name: "payments", filter: { type: "pay" })
      expect(named.apply(txn)).to eq(txn)
    end

    it "returns nil if filter does not match" do
      named = described_class.new(name: "payments", filter: { type: "axfer" })
      expect(named.apply(txn)).to be_nil
    end

    it "applies mapper if provided and filter matches" do
      mapper = ->(t) { { id: t["id"], amount: t.dig("payment-transaction", "amount") } }
      named = described_class.new(name: "payments", filter: { type: "pay" }, mapper: mapper)
      result = named.apply(txn)
      expect(result).to eq({ id: "TXN123", amount: 1000 })
    end
  end
end
