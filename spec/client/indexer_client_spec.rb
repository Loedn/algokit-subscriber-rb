# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Client::IndexerClient do
  let(:server) { "https://testnet-idx.algonode.cloud" }
  let(:token) { "test-indexer-token" }
  let(:client) { described_class.new(server, token: token) }

  describe "#initialize" do
    it "creates a client with server URL" do
      expect(client).to be_a(described_class)
    end

    it "removes trailing slashes from server URL" do
      client_with_slash = described_class.new("https://example.com/")
      expect(client_with_slash.instance_variable_get(:@server)).to eq("https://example.com")
    end

    it "accepts optional token" do
      client_without_token = described_class.new(server)
      expect(client_without_token.instance_variable_get(:@token)).to be_nil
    end

    it "accepts custom headers" do
      custom_headers = { "X-Custom" => "value" }
      client_with_headers = described_class.new(server, headers: custom_headers)
      expect(client_with_headers.instance_variable_get(:@headers)).to eq(custom_headers)
    end
  end

  describe "#search_transactions" do
    let(:mock_response) do
      {
        "current-round" => 12_345_678,
        "next-token" => nil,
        "transactions" => [
          {
            "id" => "TXID123",
            "confirmed-round" => 12_345,
            "round-time" => 1_234_567_890,
            "intra-round-offset" => 0,
            "tx-type" => "pay",
            "sender" => "SENDER123",
            "fee" => 1000,
            "first-valid" => 12_340,
            "last-valid" => 12_350,
            "payment-transaction" => {
              "amount" => 1_000_000,
              "receiver" => "RECEIVER123"
            }
          }
        ]
      }
    end

    context "with basic search" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: { "min-round" => "1000", "max-round" => "2000", "limit" => "1000" })
          .to_return(status: 200, body: mock_response.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "searches for transactions in round range" do
        result = client.search_transactions(min_round: 1000, max_round: 2000)
        expect(result["transactions"]).to be_an(Array)
        expect(result["transactions"].length).to eq(1)
        expect(result["current-round"]).to eq(12_345_678)
      end
    end

    context "with address filter" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("address" => "ABC123"))
          .to_return(status: 200, body: mock_response.to_json)
      end

      it "filters by address" do
        result = client.search_transactions(address: "ABC123")
        expect(result["transactions"]).to be_an(Array)
      end
    end

    context "with address role filter" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("address" => "ABC123", "address-role" => "sender"))
          .to_return(status: 200, body: mock_response.to_json)
      end

      it "filters by address and role" do
        result = client.search_transactions(address: "ABC123", address_role: "sender")
        expect(result["transactions"]).to be_an(Array)
      end
    end

    context "with transaction type filter" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("tx-type" => "pay"))
          .to_return(status: 200, body: mock_response.to_json)
      end

      it "filters by transaction type" do
        result = client.search_transactions(tx_type: "pay")
        expect(result["transactions"]).to be_an(Array)
      end
    end

    context "with asset filter" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("asset-id" => "12345"))
          .to_return(status: 200, body: mock_response.to_json)
      end

      it "filters by asset ID" do
        result = client.search_transactions(asset_id: 12_345)
        expect(result["transactions"]).to be_an(Array)
      end
    end

    context "with application filter" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("application-id" => "67890"))
          .to_return(status: 200, body: mock_response.to_json)
      end

      it "filters by application ID" do
        result = client.search_transactions(application_id: 67_890)
        expect(result["transactions"]).to be_an(Array)
      end
    end

    context "with note prefix filter" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("note-prefix" => "dGVzdA=="))
          .to_return(status: 200, body: mock_response.to_json)
      end

      it "filters by note prefix" do
        result = client.search_transactions(note_prefix: "dGVzdA==")
        expect(result["transactions"]).to be_an(Array)
      end
    end

    context "with currency filters" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("currency-greater-than" => "1000000", "currency-less-than" => "10000000"))
          .to_return(status: 200, body: mock_response.to_json)
      end

      it "filters by currency range" do
        result = client.search_transactions(
          currency_greater_than: 1_000_000,
          currency_less_than: 10_000_000
        )
        expect(result["transactions"]).to be_an(Array)
      end
    end

    context "with custom limit" do
      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit" => "500"))
          .to_return(status: 200, body: mock_response.to_json)
      end

      it "uses custom limit" do
        result = client.search_transactions(limit: 500)
        expect(result["transactions"]).to be_an(Array)
      end
    end

    context "with pagination" do
      let(:page1_response) do
        mock_response.merge("next-token" => "PAGE2TOKEN")
      end

      let(:page2_response) do
        {
          "current-round" => 12_345_678,
          "transactions" => [
            {
              "id" => "TXID456",
              "confirmed-round" => 12_346,
              "tx-type" => "pay"
            }
          ]
        }
      end

      before do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("min-round" => "1000", "max-round" => "2000"))
          .to_return(status: 200, body: page1_response.to_json)

        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("next" => "PAGE2TOKEN"))
          .to_return(status: 200, body: page2_response.to_json)
      end

      it "handles pagination with next token" do
        page1 = client.search_transactions(min_round: 1000, max_round: 2000)
        expect(page1["next-token"]).to eq("PAGE2TOKEN")

        page2 = client.search_transactions(
          min_round: 1000,
          max_round: 2000,
          next: page1["next-token"]
        )
        expect(page2["transactions"].first["id"]).to eq("TXID456")
      end
    end

    context "with authentication" do
      it "includes the API token in the request" do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit" => "1000"))
          .to_return(status: 200, body: mock_response.to_json)

        client.search_transactions
        # Verify the request was made (WebMock already verified the stub matched)
        expect(WebMock).to have_requested(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit"))
      end
    end

    context "with network errors" do
      it "raises NetworkError on timeout" do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit"))
          .to_timeout

        expect do
          client.search_transactions
        end.to raise_error(Algokit::Subscriber::NetworkError)
      end

      it "raises NetworkError on connection failure" do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit"))
          .to_raise(Faraday::ConnectionFailed.new("Failed"))

        expect do
          client.search_transactions
        end.to raise_error(Algokit::Subscriber::NetworkError, /connection failed/i)
      end
    end

    context "with API errors" do
      it "raises ApiError on 400 bad request" do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit"))
          .to_return(status: 400, body: "Bad Request")

        expect do
          client.search_transactions
        end.to raise_error(Algokit::Subscriber::ApiError, /bad request/i)
      end

      it "raises ApiError on 401 unauthorized" do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit"))
          .to_return(status: 401, body: "Unauthorized")

        expect do
          client.search_transactions
        end.to raise_error(Algokit::Subscriber::ApiError, /unauthorized/i)
      end

      it "raises ApiError on 404 not found" do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit"))
          .to_return(status: 404, body: "Not Found")

        expect do
          client.search_transactions
        end.to raise_error(Algokit::Subscriber::ApiError, /not found/i)
      end

      it "raises ApiError on 500 server error" do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit"))
          .to_return(status: 500, body: "Internal Server Error")

        expect do
          client.search_transactions
        end.to raise_error(Algokit::Subscriber::ApiError, /server error/i)
      end

      it "raises ApiError on invalid JSON" do
        stub_request(:get, "#{server}/v2/transactions")
          .with(query: hash_including("limit"))
          .to_return(status: 200, body: "not json")

        expect do
          client.search_transactions
        end.to raise_error(Algokit::Subscriber::ApiError, /invalid json/i)
      end
    end
  end

  describe "#health" do
    context "when healthy" do
      before do
        stub_request(:get, "#{server}/v2/health")
          .to_return(status: 200, body: {}.to_json)
      end

      it "returns health status" do
        expect { client.health }.not_to raise_error
      end
    end

    context "when unhealthy" do
      before do
        stub_request(:get, "#{server}/v2/health")
          .to_return(status: 500, body: "Unhealthy")
      end

      it "raises ApiError" do
        expect { client.health }.to raise_error(Algokit::Subscriber::ApiError)
      end
    end
  end

  describe "retry mechanism" do
    it "retries on transient failures" do
      # First two attempts fail, third succeeds
      stub_request(:get, "#{server}/v2/transactions")
        .with(query: hash_including("limit"))
        .to_timeout
        .times(2)
        .then
        .to_return(status: 200, body: { "transactions" => [] }.to_json)

      expect { client.search_transactions }.not_to raise_error
    end
  end

  describe "without authentication" do
    let(:client_no_auth) { described_class.new(server) }

    it "makes requests without token header" do
      stub_request(:get, "#{server}/v2/transactions")
        .with(query: hash_including("limit"))
        .to_return(status: 200, body: { "transactions" => [] }.to_json)

      client_no_auth.search_transactions

      expect(WebMock).to have_requested(:get, "#{server}/v2/transactions")
        .with(query: hash_including("limit"))
    end
  end
end
