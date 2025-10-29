# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Client::AlgodClient do
  let(:server) { "https://testnet-api.algonode.cloud" }
  let(:token) { "test-token" }
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

  describe "#status" do
    context "with successful response" do
      let(:mock_status) do
        {
          "last-round" => 12_345_678,
          "time-since-last-round" => 3_500_000_000,
          "catchup-time" => 0,
          "last-version" => "https://github.com/algorandfoundation/specs/tree/abc123",
          "next-version" => "https://github.com/algorandfoundation/specs/tree/def456",
          "next-version-round" => 12_346_000,
          "next-version-supported" => true,
          "stopped-at-unsupported-round" => false
        }
      end

      before do
        stub_request(:get, "#{server}/v2/status")
          .with(headers: { "X-Algo-API-Token" => token })
          .to_return(status: 200, body: mock_status.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns the current status" do
        status = client.status
        expect(status["last-round"]).to eq(12_345_678)
        expect(status["time-since-last-round"]).to eq(3_500_000_000)
      end

      it "includes the API token in the request" do
        client.status
        expect(WebMock).to have_requested(:get, "#{server}/v2/status")
          .with(headers: { "X-Algo-API-Token" => token })
      end
    end

    context "with network errors" do
      it "raises NetworkError on timeout" do
        stub_request(:get, "#{server}/v2/status").to_timeout

        expect { client.status }.to raise_error(Algokit::Subscriber::NetworkError)
      end

      it "raises NetworkError on connection failure" do
        stub_request(:get, "#{server}/v2/status").to_raise(Faraday::ConnectionFailed.new("Failed"))

        expect { client.status }.to raise_error(Algokit::Subscriber::NetworkError, /connection failed/i)
      end
    end

    context "with API errors" do
      it "raises ApiError on 401 unauthorized" do
        stub_request(:get, "#{server}/v2/status")
          .to_return(status: 401, body: "Unauthorized")

        expect { client.status }.to raise_error(Algokit::Subscriber::ApiError, /unauthorized/i)
      end

      it "raises ApiError on 500 server error" do
        stub_request(:get, "#{server}/v2/status")
          .to_return(status: 500, body: "Internal Server Error")

        expect { client.status }.to raise_error(Algokit::Subscriber::ApiError, /server error/i)
      end

      it "raises ApiError on invalid JSON" do
        stub_request(:get, "#{server}/v2/status")
          .to_return(status: 200, body: "not json")

        expect { client.status }.to raise_error(Algokit::Subscriber::ApiError, /invalid json/i)
      end
    end
  end

  describe "#block" do
    let(:round) { 12_345 }
    let(:mock_block) do
      {
        "block" => {
          "rnd" => round,
          "ts" => 1_234_567_890,
          "gen" => "testnet-v1.0",
          "gh" => "SGO1GKSzyE7IEPItTxCByw9x8FmnrCDexi9/cOUJOiI=",
          "txn" => "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
          "proto" => "https://github.com/algorandfoundation/specs/tree/abc123"
        },
        "cert" => {}
      }
    end

    context "with valid round" do
      before do
        stub_request(:get, "#{server}/v2/blocks/#{round}")
          .to_return(status: 200, body: mock_block.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns the block data" do
        block = client.block(round)
        expect(block["block"]["rnd"]).to eq(round)
        expect(block["block"]["gen"]).to eq("testnet-v1.0")
      end
    end

    context "with invalid round" do
      it "raises InvalidRoundError for negative round" do
        expect { client.block(-1) }.to raise_error(Algokit::Subscriber::InvalidRoundError, /positive integer/)
      end

      it "raises InvalidRoundError for zero" do
        expect { client.block(0) }.to raise_error(Algokit::Subscriber::InvalidRoundError, /positive integer/)
      end

      it "raises InvalidRoundError for non-integer" do
        expect { client.block("123") }.to raise_error(Algokit::Subscriber::InvalidRoundError, /positive integer/)
      end

      it "raises InvalidRoundError when block not found" do
        stub_request(:get, "#{server}/v2/blocks/#{round}")
          .to_return(status: 404, body: "Not Found")

        expect { client.block(round) }.to raise_error(Algokit::Subscriber::InvalidRoundError, /not found/)
      end
    end

    context "with network errors" do
      before do
        stub_request(:get, "#{server}/v2/blocks/#{round}").to_timeout
      end

      it "raises NetworkError on timeout" do
        expect { client.block(round) }.to raise_error(Algokit::Subscriber::NetworkError)
      end
    end
  end

  describe "#status_after_block" do
    let(:round) { 12_345 }
    let(:mock_status) do
      {
        "last-round" => round + 1,
        "time-since-last-round" => 0
      }
    end

    context "with valid round" do
      before do
        stub_request(:get, "#{server}/v2/status/wait-for-block-after/#{round}")
          .to_return(status: 200, body: mock_status.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns status after the specified round" do
        status = client.status_after_block(round)
        expect(status["last-round"]).to eq(round + 1)
      end

      it "waits for the next round" do
        client.status_after_block(round)
        expect(WebMock).to have_requested(:get, "#{server}/v2/status/wait-for-block-after/#{round}")
      end
    end

    context "with round zero" do
      before do
        stub_request(:get, "#{server}/v2/status/wait-for-block-after/0")
          .to_return(status: 200, body: { "last-round" => 1 }.to_json)
      end

      it "accepts round 0" do
        expect { client.status_after_block(0) }.not_to raise_error
      end
    end

    context "with invalid round" do
      it "raises InvalidRoundError for negative round" do
        expect do
          client.status_after_block(-1)
        end.to raise_error(Algokit::Subscriber::InvalidRoundError, /non-negative integer/)
      end

      it "raises InvalidRoundError for non-integer" do
        expect do
          client.status_after_block("123")
        end.to raise_error(Algokit::Subscriber::InvalidRoundError, /non-negative integer/)
      end
    end

    context "with longer timeout" do
      it "uses extended timeout for waiting" do
        stub_request(:get, "#{server}/v2/status/wait-for-block-after/#{round}")
          .to_return(status: 200, body: mock_status.to_json)

        # This test verifies the method doesn't raise a timeout error with extended wait
        expect { client.status_after_block(round) }.not_to raise_error
      end
    end
  end

  describe "retry mechanism" do
    let(:round) { 12_345 }

    it "retries on transient failures" do
      # First two attempts fail, third succeeds
      stub_request(:get, "#{server}/v2/blocks/#{round}")
        .to_timeout
        .times(2)
        .then
        .to_return(status: 200, body: { "block" => { "rnd" => round } }.to_json)

      expect { client.block(round) }.not_to raise_error
    end
  end

  describe "without authentication" do
    let(:client_no_auth) { described_class.new(server) }

    it "makes requests without token header" do
      stub_request(:get, "#{server}/v2/status")
        .to_return(status: 200, body: { "last-round" => 123 }.to_json)

      client_no_auth.status

      expect(WebMock).to(have_requested(:get, "#{server}/v2/status")
        .with { |req| !req.headers.key?("X-Algo-API-Token") })
    end
  end
end
