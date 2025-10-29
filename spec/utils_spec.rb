# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::Utils do
  describe ".chunk_array" do
    it "chunks array into specified size" do
      result = described_class.chunk_array([1, 2, 3, 4, 5], 2)
      expect(result).to eq([[1, 2], [3, 4], [5]])
    end

    it "returns empty array for empty input" do
      result = described_class.chunk_array([], 2)
      expect(result).to eq([])
    end

    it "returns single chunk if array is smaller than chunk size" do
      result = described_class.chunk_array([1, 2], 5)
      expect(result).to eq([[1, 2]])
    end

    it "handles chunk size of 1" do
      result = described_class.chunk_array([1, 2, 3], 1)
      expect(result).to eq([[1], [2], [3]])
    end
  end

  describe ".range" do
    it "creates range from start to stop" do
      result = described_class.range(1, 5)
      expect(result).to eq([1, 2, 3, 4, 5])
    end

    it "returns empty array if start > stop" do
      result = described_class.range(5, 1)
      expect(result).to eq([])
    end

    it "returns single element if start == stop" do
      result = described_class.range(3, 3)
      expect(result).to eq([3])
    end
  end

  describe ".sleep_with_cancellation" do
    it "sleeps for the specified duration" do
      start = Time.now
      described_class.sleep_with_cancellation(0.1, nil)
      elapsed = Time.now - start
      expect(elapsed).to be >= 0.1
    end

    it "returns immediately if stop signal is set" do
      stop_signal = Concurrent::Event.new
      stop_signal.set
      start = Time.now
      described_class.sleep_with_cancellation(1, stop_signal)
      elapsed = Time.now - start
      expect(elapsed).to be < 0.5
    end
  end

  describe ".method_signature_to_selector" do
    it "generates 4-byte selector from signature" do
      selector = described_class.method_signature_to_selector("transfer(address,uint64)")
      expect(selector).to be_a(String)
      expect(selector.length).to eq(4)
    end

    it "generates consistent selectors" do
      selector1 = described_class.method_signature_to_selector("test()")
      selector2 = described_class.method_signature_to_selector("test()")
      expect(selector1).to eq(selector2)
    end
  end

  describe ".decode_note" do
    it "decodes base64 note" do
      encoded = Base64.strict_encode64("Hello World")
      decoded = described_class.decode_note(encoded)
      expect(decoded).to eq("Hello World")
    end

    it "returns nil for nil input" do
      expect(described_class.decode_note(nil)).to be_nil
    end
  end

  describe ".encode_note" do
    it "encodes note to base64" do
      encoded = described_class.encode_note("Hello World")
      expect(encoded).to eq(Base64.strict_encode64("Hello World"))
    end

    it "returns nil for nil input" do
      expect(described_class.encode_note(nil)).to be_nil
    end
  end

  describe ".decode_app_args" do
    it "decodes array of base64 app args" do
      args = ["SGVsbG8=", "V29ybGQ="]
      decoded = described_class.decode_app_args(args)
      expect(decoded).to eq(%w[Hello World])
    end

    it "returns empty array for nil input" do
      expect(described_class.decode_app_args(nil)).to eq([])
    end

    it "returns empty array for empty array" do
      expect(described_class.decode_app_args([])).to eq([])
    end
  end

  describe ".encode_app_args" do
    it "encodes array of app args to base64" do
      args = %w[Hello World]
      encoded = described_class.encode_app_args(args)
      expect(encoded).to eq(["SGVsbG8=", "V29ybGQ="])
    end

    it "returns empty array for nil input" do
      expect(described_class.encode_app_args(nil)).to eq([])
    end
  end
end
