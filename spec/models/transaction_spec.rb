# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Models::Transaction do
  describe "payment transaction" do
    let(:payment_data) do
      {
        "id" => "TXID123",
        "tx-type" => "pay",
        "sender" => "SENDER123",
        "confirmed-round" => 12_345,
        "round-time" => 1_234_567_890,
        "intra-round-offset" => 0,
        "fee" => 1000,
        "first-valid" => 12_340,
        "last-valid" => 12_350,
        "note" => "dGVzdCBub3Rl", # "test note" in base64
        "payment-transaction" => {
          "receiver" => "RECEIVER123",
          "amount" => 1_000_000,
          "close-remainder-to" => nil
        }
      }
    end

    let(:transaction) { described_class.new(payment_data) }

    it "parses payment transaction fields" do
      expect(transaction.id).to eq("TXID123")
      expect(transaction.type).to eq("pay")
      expect(transaction.sender).to eq("SENDER123")
      expect(transaction.receiver).to eq("RECEIVER123")
      expect(transaction.amount).to eq(1_000_000)
      expect(transaction.round).to eq(12_345)
      expect(transaction.fee).to eq(1000)
    end

    it "identifies as payment transaction" do
      expect(transaction.payment?).to be true
      expect(transaction.asset_transfer?).to be false
      expect(transaction.application_call?).to be false
    end

    it "decodes note text" do
      expect(transaction.note_text).to eq("test note")
    end

    it "converts to hash" do
      hash = transaction.to_h
      expect(hash[:id]).to eq("TXID123")
      expect(hash[:type]).to eq("pay")
      expect(hash[:amount]).to eq(1_000_000)
    end
  end

  describe "asset transfer transaction" do
    let(:asset_transfer_data) do
      {
        "id" => "TXID456",
        "tx-type" => "axfer",
        "sender" => "SENDER456",
        "confirmed-round" => 12_346,
        "asset-transfer-transaction" => {
          "asset-id" => 31_566_704,
          "amount" => 1_000_000,
          "receiver" => "RECEIVER456",
          "close-to" => nil
        }
      }
    end

    let(:transaction) { described_class.new(asset_transfer_data) }

    it "parses asset transfer fields" do
      expect(transaction.id).to eq("TXID456")
      expect(transaction.type).to eq("axfer")
      expect(transaction.asset_id).to eq(31_566_704)
      expect(transaction.asset_amount).to eq(1_000_000)
      expect(transaction.asset_receiver).to eq("RECEIVER456")
    end

    it "identifies as asset transfer" do
      expect(transaction.asset_transfer?).to be true
      expect(transaction.payment?).to be false
    end
  end

  describe "asset config transaction" do
    let(:asset_config_data) do
      {
        "id" => "TXID789",
        "tx-type" => "acfg",
        "sender" => "CREATOR789",
        "confirmed-round" => 12_347,
        "created-asset-index" => 123_456,
        "asset-config-transaction" => {
          "params" => {
            "name" => "MyToken",
            "unit-name" => "MTK",
            "total" => 1_000_000_000,
            "decimals" => 6
          }
        }
      }
    end

    let(:transaction) { described_class.new(asset_config_data) }

    it "parses asset config fields" do
      expect(transaction.id).to eq("TXID789")
      expect(transaction.type).to eq("acfg")
      expect(transaction.created_asset_index).to eq(123_456)
      expect(transaction.asset_params).to be_a(Hash)
      expect(transaction.asset_params["name"]).to eq("MyToken")
    end

    it "identifies as asset config" do
      expect(transaction.asset_config?).to be true
    end

    it "knows it created an asset" do
      expect(transaction.created_asset?).to be true
      expect(transaction.created_application?).to be false
    end
  end

  describe "application call transaction" do
    let(:app_call_data) do
      {
        "id" => "TXIDABC",
        "tx-type" => "appl",
        "sender" => "CALLER123",
        "confirmed-round" => 12_348,
        "created-application-index" => 67_890,
        "logs" => ["bG9nMQ==", "bG9nMg=="],
        "application-transaction" => {
          "application-id" => 0,
          "application-args" => ["YXJnMQ==", "YXJnMg=="],
          "accounts" => %w[ACCOUNT1 ACCOUNT2],
          "foreign-apps" => [100, 200],
          "foreign-assets" => [300, 400],
          "on-completion" => "noop"
        }
      }
    end

    let(:transaction) { described_class.new(app_call_data) }

    it "parses application call fields" do
      expect(transaction.id).to eq("TXIDABC")
      expect(transaction.type).to eq("appl")
      expect(transaction.application_id).to eq(0)
      expect(transaction.created_application_index).to eq(67_890)
      expect(transaction.logs).to eq(["bG9nMQ==", "bG9nMg=="])
      expect(transaction.application_args).to be_an(Array)
      expect(transaction.accounts).to eq(%w[ACCOUNT1 ACCOUNT2])
      expect(transaction.foreign_apps).to eq([100, 200])
      expect(transaction.on_completion).to eq("noop")
    end

    it "identifies as application call" do
      expect(transaction.application_call?).to be true
    end

    it "knows it created an application" do
      expect(transaction.created_application?).to be true
      expect(transaction.created_asset?).to be false
    end
  end

  describe "with inner transactions" do
    let(:transaction_with_inner) do
      {
        "id" => "PARENT123",
        "tx-type" => "appl",
        "sender" => "SENDER123",
        "confirmed-round" => 12_349,
        "inner-txns" => [
          {
            "id" => "INNER1",
            "tx-type" => "pay",
            "sender" => "INNERSENDER1",
            "payment-transaction" => {
              "receiver" => "INNERRECEIVER1",
              "amount" => 500_000
            }
          },
          {
            "id" => "INNER2",
            "tx-type" => "axfer",
            "sender" => "INNERSENDER2",
            "asset-transfer-transaction" => {
              "asset-id" => 12_345,
              "amount" => 100,
              "receiver" => "INNERRECEIVER2"
            }
          }
        ]
      }
    end

    let(:transaction) { described_class.new(transaction_with_inner) }

    it "parses inner transactions" do
      expect(transaction.inner_txns).to be_an(Array)
      expect(transaction.inner_txns.length).to eq(2)
      expect(transaction.inner_txns.first).to be_a(described_class)
      expect(transaction.inner_txns.first.id).to eq("INNER1")
      expect(transaction.inner_txns.first.payment?).to be true
      expect(transaction.inner_txns.last.asset_transfer?).to be true
    end

    it "includes inner transaction count in to_h" do
      hash = transaction.to_h
      expect(hash[:inner_txns_count]).to eq(2)
    end
  end

  describe "#note_text" do
    context "with valid base64 note" do
      let(:transaction_data) { { "note" => Base64.strict_encode64("Hello World") } }
      let(:transaction) { described_class.new(transaction_data) }

      it "decodes the note" do
        expect(transaction.note_text).to eq("Hello World")
      end
    end

    context "with no note" do
      let(:transaction_data) { {} }
      let(:transaction) { described_class.new(transaction_data) }

      it "returns nil" do
        expect(transaction.note_text).to be_nil
      end
    end

    context "with invalid base64" do
      let(:transaction_data) { { "note" => "not-valid-base64!!!" } }
      let(:transaction) { described_class.new(transaction_data) }

      it "decodes lenient base64 (Ruby Base64 is permissive)" do
        # Ruby's Base64.decode64 is very lenient and will decode almost anything
        # It only returns nil if note itself is nil
        expect(transaction.note_text).not_to be_nil
      end
    end
  end
end
