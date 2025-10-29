# frozen_string_literal: true

require "spec_helper"

RSpec.describe Algokit::Subscriber::AsyncEventEmitter do
  let(:emitter) { described_class.new }

  describe "#on" do
    it "registers an event handler" do
      handler = proc { |data| data }
      result = emitter.on("test_event", &handler)
      expect(result).to eq(handler)
      expect(emitter.listener_count("test_event")).to eq(1)
    end

    it "allows multiple handlers for same event" do
      emitter.on("test_event") { |x| x }
      emitter.on("test_event") { |x| x * 2 }
      expect(emitter.listener_count("test_event")).to eq(2)
    end
  end

  describe "#off" do
    it "removes a specific handler" do
      handler = proc { |x| x }
      emitter.on("test_event", &handler)
      expect(emitter.listener_count("test_event")).to eq(1)

      emitter.off("test_event", handler)
      expect(emitter.listener_count("test_event")).to eq(0)
    end

    it "removes all handlers when no handler specified" do
      emitter.on("test_event") { |x| x }
      emitter.on("test_event") { |x| x * 2 }
      expect(emitter.listener_count("test_event")).to eq(2)

      emitter.off("test_event")
      expect(emitter.listener_count("test_event")).to eq(0)
    end
  end

  describe "#emit" do
    it "calls all registered handlers" do
      results = []
      emitter.on("test_event") { |x| results << x }
      emitter.on("test_event") { |x| results << (x * 2) }

      emitter.emit("test_event", 5)
      expect(results).to eq([5, 10])
    end

    it "passes multiple arguments to handlers" do
      result = nil
      emitter.on("test_event") { |a, b, c| result = a + b + c }

      emitter.emit("test_event", 1, 2, 3)
      expect(result).to eq(6)
    end

    it "continues calling handlers even if one raises error" do
      results = []
      emitter.on("test_event") { |x| results << x }
      emitter.on("test_event") { raise "error" }
      emitter.on("test_event") { |x| results << (x * 2) }

      expect { emitter.emit("test_event", 5) }.not_to raise_error
      expect(results).to eq([5, 10])
    end

    it "does nothing when no handlers registered" do
      expect { emitter.emit("nonexistent_event", 1) }.not_to raise_error
    end
  end

  describe "#emit_async" do
    it "calls handlers asynchronously" do
      results = []
      mutex = Mutex.new

      emitter.on("test_event") do |x|
        sleep 0.01
        mutex.synchronize { results << x }
      end

      emitter.on("test_event") do |x|
        sleep 0.01
        mutex.synchronize { results << (x * 2) }
      end

      promises = emitter.emit_async("test_event", 5)
      promises.each(&:wait)

      expect(results.sort).to eq([5, 10])
    end

    it "returns array of promises" do
      emitter.on("test_event") { |x| x }
      emitter.on("test_event") { |x| x * 2 }

      promises = emitter.emit_async("test_event", 5)
      expect(promises).to be_an(Array)
      expect(promises.length).to eq(2)
      expect(promises.all? { |p| p.is_a?(Concurrent::Promise) }).to be true
    end

    it "handles errors in async handlers gracefully" do
      results = []
      emitter.on("test_event") { |x| results << x }
      emitter.on("test_event") { raise "async error" }
      emitter.on("test_event") { |x| results << (x * 2) }

      promises = emitter.emit_async("test_event", 5)
      promises.each(&:wait)

      expect(results.sort).to eq([5, 10])
    end
  end

  describe "#listener_count" do
    it "returns correct count" do
      expect(emitter.listener_count("test_event")).to eq(0)
      emitter.on("test_event") { |x| x }
      expect(emitter.listener_count("test_event")).to eq(1)
      emitter.on("test_event") { |x| x }
      expect(emitter.listener_count("test_event")).to eq(2)
    end
  end

  describe "#clear_all" do
    it "removes all event handlers" do
      emitter.on("event1") { |x| x }
      emitter.on("event2") { |x| x }
      expect(emitter.listener_count("event1")).to eq(1)
      expect(emitter.listener_count("event2")).to eq(1)

      emitter.clear_all
      expect(emitter.listener_count("event1")).to eq(0)
      expect(emitter.listener_count("event2")).to eq(0)
    end
  end

  describe "thread safety" do
    it "handles concurrent registrations" do
      threads = 10.times.map do
        Thread.new do
          100.times { emitter.on("test_event") { |x| x } }
        end
      end

      threads.each(&:join)
      expect(emitter.listener_count("test_event")).to eq(1000)
    end

    it "handles concurrent emissions" do
      results = []
      mutex = Mutex.new
      emitter.on("test_event") { |x| mutex.synchronize { results << x } }

      threads = 10.times.map do |i|
        Thread.new { emitter.emit("test_event", i) }
      end

      threads.each(&:join)
      expect(results.sort).to eq((0..9).to_a)
    end
  end
end
