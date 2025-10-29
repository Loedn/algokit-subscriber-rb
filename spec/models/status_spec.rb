# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Models::Status do
  let(:status_data) do
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

  let(:status) { described_class.new(status_data) }

  describe "#initialize" do
    it "parses all status fields" do
      expect(status.last_round).to eq(12_345_678)
      expect(status.time_since_last_round).to eq(3_500_000_000)
      expect(status.catchup_time).to eq(0)
      expect(status.last_version).to include("abc123")
      expect(status.next_version).to include("def456")
      expect(status.next_version_round).to eq(12_346_000)
      expect(status.next_version_supported).to be true
      expect(status.stopped_at_unsupported_round).to be false
    end
  end

  describe "#to_h" do
    it "converts to hash" do
      hash = status.to_h
      expect(hash[:last_round]).to eq(12_345_678)
      expect(hash[:catchup_time]).to eq(0)
    end
  end

  describe "#caught_up?" do
    context "when catchup_time is 0" do
      it "returns true" do
        expect(status.caught_up?).to be true
      end
    end

    context "when catchup_time is greater than 0" do
      let(:status_data) { { "catchup-time" => 5000 } }

      it "returns false" do
        expect(status.caught_up?).to be false
      end
    end
  end

  describe "#time_since_last_round_seconds" do
    it "converts nanoseconds to seconds" do
      expect(status.time_since_last_round_seconds).to be_within(0.01).of(3.5)
    end

    context "when time_since_last_round is nil" do
      let(:status_data) { {} }

      it "returns nil" do
        expect(status.time_since_last_round_seconds).to be_nil
      end
    end
  end
end
