# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Transform do
  let(:block_metadata) do
    Algokit::Subscriber::Types::BlockMetadata.new(
      round: 1000,
      timestamp: 1_700_000_000,
      genesis_id: "testnet-v1.0",
      genesis_hash: "SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI="
    )
  end

  describe ".algod_transaction_to_indexer" do
    context "payment transaction" do
      let(:algod_txn) do
        {
          "txn" => {
            "type" => "pay",
            "snd" => "SENDER",
            "rcv" => "RECEIVER",
            "amt" => 1_000_000,
            "fee" => 1000,
            "fv" => 999,
            "lv" => 1099,
            "tx-id" => "TXN123"
          },
          "hgi" => 0
        }
      end

      it "converts payment transaction" do
        result = described_class.algod_transaction_to_indexer(algod_txn, block_metadata)

        expect(result["id"]).to eq("TXN123")
        expect(result["tx-type"]).to eq("pay")
        expect(result["sender"]).to eq("SENDER")
        expect(result["fee"]).to eq(1000)
        expect(result["confirmed-round"]).to eq(1000)
        expect(result["round-time"]).to eq(1_700_000_000)
        expect(result["payment-transaction"]["receiver"]).to eq("RECEIVER")
        expect(result["payment-transaction"]["amount"]).to eq(1_000_000)
      end
    end

    context "asset transfer transaction" do
      let(:algod_txn) do
        {
          "txn" => {
            "type" => "axfer",
            "snd" => "SENDER",
            "arcv" => "RECEIVER",
            "xaid" => 123,
            "aamt" => 500,
            "fee" => 1000,
            "fv" => 999,
            "lv" => 1099,
            "tx-id" => "AXFER123"
          },
          "hgi" => 1
        }
      end

      it "converts asset transfer transaction" do
        result = described_class.algod_transaction_to_indexer(algod_txn, block_metadata)

        expect(result["id"]).to eq("AXFER123")
        expect(result["tx-type"]).to eq("axfer")
        expect(result["asset-transfer-transaction"]["asset-id"]).to eq(123)
        expect(result["asset-transfer-transaction"]["amount"]).to eq(500)
        expect(result["asset-transfer-transaction"]["receiver"]).to eq("RECEIVER")
      end
    end

    context "application call transaction" do
      let(:algod_txn) do
        {
          "txn" => {
            "type" => "appl",
            "snd" => "SENDER",
            "apid" => 456,
            "apan" => "noop",
            "fee" => 1000,
            "fv" => 999,
            "lv" => 1099,
            "tx-id" => "APPL123"
          },
          "dt" => {
            "lg" => ["bG9nMQ==", "bG9nMg=="]
          },
          "hgi" => 2
        }
      end

      it "converts application call transaction" do
        result = described_class.algod_transaction_to_indexer(algod_txn, block_metadata)

        expect(result["id"]).to eq("APPL123")
        expect(result["tx-type"]).to eq("appl")
        expect(result["application-transaction"]["application-id"]).to eq(456)
        expect(result["application-transaction"]["on-completion"]).to eq("noop")
        expect(result["logs"]).to eq(["bG9nMQ==", "bG9nMg=="])
      end
    end

    context "inner transactions" do
      let(:algod_txn) do
        {
          "txn" => {
            "type" => "appl",
            "snd" => "SENDER",
            "apid" => 456,
            "fee" => 1000,
            "fv" => 999,
            "lv" => 1099,
            "tx-id" => "PARENT123"
          },
          "dt" => {
            "itx" => [
              {
                "txn" => {
                  "type" => "pay",
                  "snd" => "INNER_SENDER",
                  "rcv" => "INNER_RECEIVER",
                  "amt" => 500_000,
                  "fee" => 0,
                  "fv" => 999,
                  "lv" => 1099,
                  "tx-id" => "INNER123"
                }
              }
            ]
          },
          "hgi" => 0
        }
      end

      it "converts inner transactions recursively" do
        result = described_class.algod_transaction_to_indexer(algod_txn, block_metadata)

        expect(result["inner-txns"]).to be_an(Array)
        expect(result["inner-txns"].length).to eq(1)

        inner = result["inner-txns"].first
        expect(inner["id"]).to eq("INNER123")
        expect(inner["tx-type"]).to eq("pay")
        expect(inner["sender"]).to eq("INNER_SENDER")
        expect(inner["intra-round-offset"]).to eq(2)
      end
    end
  end

  describe ".extract_balance_changes" do
    context "payment transaction" do
      let(:payment_txn) do
        {
          "tx-type" => "pay",
          "sender" => "SENDER",
          "fee" => 1000,
          "payment-transaction" => {
            "receiver" => "RECEIVER",
            "amount" => 1_000_000
          }
        }
      end

      it "extracts balance changes for payment" do
        changes = described_class.extract_balance_changes(payment_txn)

        sender_change = changes.find { |c| c.address == "SENDER" }
        receiver_change = changes.find { |c| c.address == "RECEIVER" }

        expect(sender_change.amount).to eq(-1_001_000)
        expect(sender_change.roles).to include(Algokit::Subscriber::Types::BalanceChangeRole::SENDER)

        expect(receiver_change.amount).to eq(1_000_000)
        expect(receiver_change.roles).to include(Algokit::Subscriber::Types::BalanceChangeRole::RECEIVER)
      end
    end

    context "asset transfer transaction" do
      let(:asset_txn) do
        {
          "tx-type" => "axfer",
          "sender" => "SENDER",
          "fee" => 1000,
          "asset-transfer-transaction" => {
            "asset-id" => 123,
            "amount" => 500,
            "receiver" => "RECEIVER"
          }
        }
      end

      it "extracts balance changes for asset transfer" do
        changes = described_class.extract_balance_changes(asset_txn)

        algo_change = changes.find { |c| c.asset_id.zero? && c.address == "SENDER" }
        asset_sender = changes.find { |c| c.asset_id == 123 && c.address == "SENDER" }
        asset_receiver = changes.find { |c| c.asset_id == 123 && c.address == "RECEIVER" }

        expect(algo_change.amount).to eq(-1000)

        expect(asset_sender.amount).to eq(-500)
        expect(asset_receiver.amount).to eq(500)
      end
    end

    context "asset creation" do
      let(:asset_creation_txn) do
        {
          "tx-type" => "acfg",
          "sender" => "CREATOR",
          "fee" => 1000,
          "created-asset-index" => 456,
          "asset-config-transaction" => {
            "params" => {
              "total" => 1_000_000
            }
          }
        }
      end

      it "tracks asset creator balance" do
        changes = described_class.extract_balance_changes(asset_creation_txn)

        creator_change = changes.find { |c| c.asset_id == 456 }
        expect(creator_change).not_to be_nil
        expect(creator_change.amount).to eq(1_000_000)
        expect(creator_change.roles).to include(Algokit::Subscriber::Types::BalanceChangeRole::ASSET_CREATOR)
      end
    end
  end

  describe ".parse_arc28_events" do
    let(:event_groups) do
      [
        Algokit::Subscriber::Types::Arc28EventGroup.new(
          group_name: "TestEvents",
          events: [
            {
              name: "Transfer",
              args: [
                { name: "from", type: "address" },
                { name: "to", type: "address" },
                { name: "amount", type: "uint64" }
              ]
            }
          ]
        )
      ]
    end

    it "parses ARC-28 events from logs" do
      event_def = event_groups.first.events.first
      selector = event_def.selector
      from_addr = "A" * 32
      to_addr = "B" * 32
      amount = [1000].pack("Q>")

      log_data = selector + from_addr + to_addr + amount
      encoded_log = Base64.strict_encode64(log_data)

      events = described_class.parse_arc28_events([encoded_log], event_groups)

      expect(events).to be_an(Array)
      expect(events.length).to eq(1)

      event = events.first
      expect(event.group_name).to eq("TestEvents")
      expect(event.event_name).to eq("Transfer")
    end

    it "returns empty array for empty logs" do
      events = described_class.parse_arc28_events([], event_groups)
      expect(events).to eq([])
    end

    it "returns empty array for nil logs" do
      events = described_class.parse_arc28_events(nil, event_groups)
      expect(events).to eq([])
    end
  end
end
