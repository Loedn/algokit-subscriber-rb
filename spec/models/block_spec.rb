# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Models::Block do
  let(:block_data) do
    {
      "block" => {
        "rnd" => 12_345,
        "ts" => 1_234_567_890,
        "gen" => "testnet-v1.0",
        "gh" => "SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI=",
        "prev" => "PREVHASH123",
        "seed" => "SEED123",
        "txn" => "TXNROOT123",
        "txn256" => "TXNROOT256",
        "tc" => 1_234_567,
        "proposer" => "PROPOSER123",
        "proto" => "https://github.com/algorandfoundation/specs/tree/abc123",
        "rwd" => {
          "FeeSink" => "FEESINK123",
          "RewardsRecalculationRound" => 12_000,
          "RewardsLevel" => 1000,
          "RewardsPool" => "POOL123",
          "RewardsRate" => 100,
          "RewardsResidue" => 50
        }
      }
    }
  end

  let(:block) { described_class.new(block_data) }

  describe "#initialize" do
    it "parses basic block fields" do
      expect(block.round).to eq(12_345)
      expect(block.timestamp).to eq(1_234_567_890)
      expect(block.genesis_id).to eq("testnet-v1.0")
      expect(block.genesis_hash).to eq("SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI=")
      expect(block.previous_block_hash).to eq("PREVHASH123")
      expect(block.seed).to eq("SEED123")
      expect(block.txn_counter).to eq(1_234_567)
      expect(block.proposer).to eq("PROPOSER123")
    end

    it "parses rewards information" do
      expect(block.rewards).to be_a(Hash)
      expect(block.rewards[:fee_sink]).to eq("FEESINK123")
      expect(block.rewards[:rewards_level]).to eq(1000)
      expect(block.rewards[:rewards_rate]).to eq(100)
    end

    context "with upgrade state" do
      let(:block_data) do
        {
          "block" => {
            "rnd" => 12_345,
            "upgradeState" => {
              "currentProtocol" => "v1",
              "nextProtocol" => "v2",
              "nextProtocolApprovals" => 100
            }
          }
        }
      end

      it "parses upgrade state" do
        expect(block.upgrade_state).to be_a(Hash)
        expect(block.upgrade_state[:current_protocol]).to eq("v1")
        expect(block.upgrade_state[:next_protocol]).to eq("v2")
        expect(block.upgrade_state[:next_protocol_approvals]).to eq(100)
      end
    end

    context "with state proof tracking" do
      let(:block_data) do
        {
          "block" => {
            "rnd" => 12_345,
            "spt" => [
              {
                "nextRound" => 12_500,
                "onlineTotalWeight" => 1_000_000,
                "type" => 0
              }
            ]
          }
        }
      end

      it "parses state proof tracking" do
        expect(block.state_proof_tracking).to be_an(Array)
        expect(block.state_proof_tracking.first[:next_round]).to eq(12_500)
        expect(block.state_proof_tracking.first[:online_total_weight]).to eq(1_000_000)
      end
    end
  end

  describe "#to_h" do
    it "converts to hash" do
      hash = block.to_h
      expect(hash[:round]).to eq(12_345)
      expect(hash[:timestamp]).to eq(1_234_567_890)
      expect(hash[:genesis_id]).to eq("testnet-v1.0")
      expect(hash[:rewards]).to be_a(Hash)
    end

    it "excludes nil values" do
      minimal_block = described_class.new({ "block" => { "rnd" => 1 } })
      hash = minimal_block.to_h
      expect(hash.keys).not_to include(:upgrade_state)
      expect(hash.keys).not_to include(:state_proof_tracking)
    end
  end
end
