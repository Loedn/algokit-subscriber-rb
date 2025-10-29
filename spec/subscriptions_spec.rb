# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Subscriptions do
  let(:algod) { instance_double(Algokit::Subscriber::Client::AlgodClient) }
  let(:indexer) { instance_double(Algokit::Subscriber::Client::IndexerClient) }

  let(:config) do
    Algokit::Subscriber::Types::SubscriptionConfig.new(
      filters: [
        {
          name: "payments",
          filter: { type: "pay", min_amount: 1000 }
        }
      ],
      max_rounds_to_sync: 10,
      max_indexer_rounds_to_sync: 100,
      sync_behaviour: Algokit::Subscriber::Types::SyncBehaviour::CATCHUP_WITH_INDEXER
    )
  end

  describe ".get_subscribed_transactions" do
    context "when already at current round" do
      it "returns empty result" do
        result = described_class.get_subscribed_transactions(
          config: config,
          watermark: 1000,
          current_round: 1000,
          algod: algod
        )

        expect(result.starting_watermark).to eq(1000)
        expect(result.new_watermark).to eq(1000)
        expect(result.synced_round_range).to be_empty
        expect(result.subscribed_transactions).to be_empty
      end
    end

    context "when ahead of current round" do
      it "returns empty result" do
        result = described_class.get_subscribed_transactions(
          config: config,
          watermark: 1001,
          current_round: 1000,
          algod: algod
        )

        expect(result.new_watermark).to eq(1001)
        expect(result.synced_round_range).to be_empty
      end
    end

    context "syncing with algod" do
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
        allow(algod).to receive(:block).with(1001).and_return(block_data)
      end

      it "syncs blocks and filters transactions" do
        result = described_class.get_subscribed_transactions(
          config: config,
          watermark: 1000,
          current_round: 1001,
          algod: algod
        )

        expect(result.starting_watermark).to eq(1000)
        expect(result.new_watermark).to eq(1001)
        expect(result.synced_round_range).to eq([1001])
        expect(result.subscribed_transactions.length).to eq(1)

        filter_result = result.subscribed_transactions.first
        expect(filter_result.filter_name).to eq("payments")
        expect(filter_result.transactions.length).to eq(1)
        expect(filter_result.transactions.first["tx-type"]).to eq("pay")
      end
    end

    context "syncing with indexer (catchup mode)" do
      let(:indexer_response) do
        {
          "transactions" => [
            {
              "id" => "TXN456",
              "tx-type" => "pay",
              "sender" => "SENDER2",
              "confirmed-round" => 905,
              "payment-transaction" => {
                "receiver" => "RECEIVER2",
                "amount" => 10_000
              },
              "fee" => 1000
            }
          ]
        }
      end

      before do
        allow(indexer).to receive(:search_transactions).and_return(indexer_response)
      end

      it "uses indexer for large gaps" do
        result = described_class.get_subscribed_transactions(
          config: config,
          watermark: 900,
          current_round: 1000,
          algod: algod,
          indexer: indexer
        )

        expect(result.starting_watermark).to eq(900)
        expect(result.new_watermark).to eq(1000)
        expect(result.synced_round_range.length).to eq(100)
        expect(indexer).to have_received(:search_transactions).with(
          hash_including(
            min_round: 901,
            max_round: 1000,
            tx_type: "pay",
            currency_greater_than: 1000
          )
        )
      end
    end

    context "with multiple filters" do
      let(:multi_filter_config) do
        Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            { name: "payments", filter: { type: "pay" } },
            { name: "asset-transfers", filter: { type: "axfer" } }
          ],
          max_rounds_to_sync: 5
        )
      end

      let(:block_with_multiple_txns) do
        {
          "block" => {
            "rnd" => 2001,
            "ts" => 1_700_000_000,
            "gen" => "testnet-v1.0",
            "gh" => "SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI=",
            "txns" => [
              {
                "txn" => {
                  "type" => "pay",
                  "snd" => "SENDER1",
                  "rcv" => "RECEIVER1",
                  "amt" => 1000,
                  "fee" => 1000,
                  "fv" => 2000,
                  "lv" => 2100,
                  "tx-id" => "PAY1"
                }
              },
              {
                "txn" => {
                  "type" => "axfer",
                  "snd" => "SENDER2",
                  "arcv" => "RECEIVER2",
                  "xaid" => 123,
                  "aamt" => 500,
                  "fee" => 1000,
                  "fv" => 2000,
                  "lv" => 2100,
                  "tx-id" => "AXFER1"
                }
              }
            ]
          }
        }
      end

      before do
        allow(algod).to receive(:block).with(2001).and_return(block_with_multiple_txns)
      end

      it "applies multiple filters and groups results" do
        result = described_class.get_subscribed_transactions(
          config: multi_filter_config,
          watermark: 2000,
          current_round: 2001,
          algod: algod
        )

        expect(result.subscribed_transactions.length).to eq(2)

        payments = result.subscribed_transactions.find { |r| r.filter_name == "payments" }
        asset_transfers = result.subscribed_transactions.find { |r| r.filter_name == "asset-transfers" }

        expect(payments.transactions.length).to eq(1)
        expect(payments.transactions.first["tx-type"]).to eq("pay")

        expect(asset_transfers.transactions.length).to eq(1)
        expect(asset_transfers.transactions.first["tx-type"]).to eq("axfer")
      end
    end

    context "with mapper function" do
      let(:mapper_config) do
        Algokit::Subscriber::Types::SubscriptionConfig.new(
          filters: [
            {
              name: "mapped-payments",
              filter: { type: "pay" },
              mapper: ->(txn) { { id: txn["id"], amount: txn.dig("payment-transaction", "amount") } }
            }
          ],
          max_rounds_to_sync: 5
        )
      end

      let(:block_data) do
        {
          "block" => {
            "rnd" => 3001,
            "ts" => 1_700_000_000,
            "gen" => "testnet-v1.0",
            "gh" => "SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI=",
            "txns" => [
              {
                "txn" => {
                  "type" => "pay",
                  "snd" => "SENDER",
                  "rcv" => "RECEIVER",
                  "amt" => 2000,
                  "fee" => 1000,
                  "fv" => 3000,
                  "lv" => 3100,
                  "tx-id" => "MAPPED1"
                }
              }
            ]
          }
        }
      end

      before do
        allow(algod).to receive(:block).with(3001).and_return(block_data)
      end

      it "applies mapper to matched transactions" do
        result = described_class.get_subscribed_transactions(
          config: mapper_config,
          watermark: 3000,
          current_round: 3001,
          algod: algod
        )

        mapped = result.subscribed_transactions.first
        expect(mapped.transactions.length).to eq(1)
        expect(mapped.transactions.first).to eq({ id: "MAPPED1", amount: 2000 })
      end
    end

    context "with inner transactions" do
      let(:block_with_inner) do
        {
          "block" => {
            "rnd" => 4001,
            "ts" => 1_700_000_000,
            "gen" => "testnet-v1.0",
            "gh" => "SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI=",
            "txns" => [
              {
                "txn" => {
                  "type" => "appl",
                  "snd" => "APP_CALLER",
                  "apid" => 456,
                  "fee" => 1000,
                  "fv" => 4000,
                  "lv" => 4100,
                  "tx-id" => "APP1"
                },
                "dt" => {
                  "itx" => [
                    {
                      "txn" => {
                        "type" => "pay",
                        "snd" => "INNER_SENDER",
                        "rcv" => "INNER_RECEIVER",
                        "amt" => 5000,
                        "fee" => 0,
                        "fv" => 4000,
                        "lv" => 4100,
                        "tx-id" => "INNER_PAY1"
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      end

      before do
        allow(algod).to receive(:block).with(4001).and_return(block_with_inner)
      end

      it "includes inner transactions in results" do
        result = described_class.get_subscribed_transactions(
          config: config,
          watermark: 4000,
          current_round: 4001,
          algod: algod
        )

        payments = result.subscribed_transactions.first
        expect(payments.transactions.length).to eq(1)
        expect(payments.transactions.first["id"]).to eq("INNER_PAY1")
      end
    end
  end

  describe ".indexer_pre_filter" do
    it "converts filter to indexer query parameters" do
      filter = Algokit::Subscriber::Types::TransactionFilter.new(
        type: "pay",
        sender: "SENDER",
        min_amount: 1000,
        max_amount: 10_000
      )

      params = described_class.send(:indexer_pre_filter, filter)

      expect(params[:tx_type]).to eq("pay")
      expect(params[:address]).to eq("SENDER")
      expect(params[:currency_greater_than]).to eq(1000)
      expect(params[:currency_less_than]).to eq(10_000)
    end

    it "handles asset and app filters" do
      filter = Algokit::Subscriber::Types::TransactionFilter.new(
        asset_id: 123,
        app_id: 456
      )

      params = described_class.send(:indexer_pre_filter, filter)

      expect(params[:asset_id]).to eq(123)
      expect(params[:application_id]).to eq(456)
    end
  end

  describe ".balance_change_matches?" do
    let(:balance_changes) do
      [
        Algokit::Subscriber::Types::BalanceChange.new(
          address: "ADDR1",
          asset_id: 0,
          amount: -5000,
          roles: ["Sender"]
        ),
        Algokit::Subscriber::Types::BalanceChange.new(
          address: "ADDR2",
          asset_id: 0,
          amount: 5000,
          roles: ["Receiver"]
        )
      ]
    end

    it "matches on address" do
      expected = [{ address: "ADDR1" }]
      expect(described_class.send(:balance_change_matches?, balance_changes, expected)).to be true
    end

    it "matches on amount range" do
      expected = [{ min_amount: 4000, max_amount: 6000 }]
      expect(described_class.send(:balance_change_matches?, balance_changes, expected)).to be true
    end

    it "matches on roles" do
      expected = [{ roles: ["Receiver"] }]
      expect(described_class.send(:balance_change_matches?, balance_changes, expected)).to be true
    end

    it "returns false when no match" do
      expected = [{ address: "ADDR3" }]
      expect(described_class.send(:balance_change_matches?, balance_changes, expected)).to be false
    end
  end
end
