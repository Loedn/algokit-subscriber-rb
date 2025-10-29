# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Types::BalanceChange do
  describe "#initialize" do
    it "creates a balance change with default values" do
      change = described_class.new(address: "TEST_ADDRESS")
      expect(change.address).to eq("TEST_ADDRESS")
      expect(change.asset_id).to eq(0)
      expect(change.amount).to eq(0)
      expect(change.roles).to eq([])
    end

    it "creates a balance change with custom values" do
      change = described_class.new(
        address: "TEST_ADDRESS",
        asset_id: 123,
        amount: 1000,
        roles: [Algokit::Subscriber::Types::BalanceChangeRole::SENDER]
      )
      expect(change.address).to eq("TEST_ADDRESS")
      expect(change.asset_id).to eq(123)
      expect(change.amount).to eq(1000)
      expect(change.roles).to eq([Algokit::Subscriber::Types::BalanceChangeRole::SENDER])
    end
  end

  describe "#algo_change?" do
    it "returns true for algo changes (asset_id = 0)" do
      change = described_class.new(address: "TEST", asset_id: 0)
      expect(change.algo_change?).to be true
    end

    it "returns false for asset changes" do
      change = described_class.new(address: "TEST", asset_id: 123)
      expect(change.algo_change?).to be false
    end
  end

  describe "#asset_change?" do
    it "returns false for algo changes" do
      change = described_class.new(address: "TEST", asset_id: 0)
      expect(change.asset_change?).to be false
    end

    it "returns true for asset changes" do
      change = described_class.new(address: "TEST", asset_id: 123)
      expect(change.asset_change?).to be true
    end
  end

  describe "#to_h" do
    it "converts to hash" do
      change = described_class.new(
        address: "TEST",
        asset_id: 123,
        amount: 500,
        roles: ["Sender"]
      )
      expect(change.to_h).to eq({
                                  address: "TEST",
                                  asset_id: 123,
                                  amount: 500,
                                  roles: ["Sender"]
                                })
    end
  end

  describe "#==" do
    it "compares balance changes correctly" do
      change1 = described_class.new(address: "A", asset_id: 1, amount: 100, roles: ["Sender"])
      change2 = described_class.new(address: "A", asset_id: 1, amount: 100, roles: ["Sender"])
      expect(change1).to eq(change2)
    end

    it "handles role order differences" do
      change1 = described_class.new(address: "A", asset_id: 1, amount: 100, roles: %w[Sender Receiver])
      change2 = described_class.new(address: "A", asset_id: 1, amount: 100, roles: %w[Receiver Sender])
      expect(change1).to eq(change2)
    end

    it "returns false for different changes" do
      change1 = described_class.new(address: "A", asset_id: 1, amount: 100)
      change2 = described_class.new(address: "B", asset_id: 1, amount: 100)
      expect(change1).not_to eq(change2)
    end
  end
end

RSpec.describe Algokit::Subscriber::Types::BalanceChangeRole do
  it "defines all expected roles" do
    expect(described_class::SENDER).to eq("Sender")
    expect(described_class::RECEIVER).to eq("Receiver")
    expect(described_class::CLOSE_TO).to eq("CloseTo")
    expect(described_class::ASSET_CREATOR).to eq("AssetCreator")
    expect(described_class::ASSET_DESTROYER).to eq("AssetDestroyer")
  end
end
