# frozen_string_literal: true

require "concurrent"

module Algokit
  module Subscriber
    class AlgorandSubscriber
      attr_reader :config, :algod, :indexer, :watermark

      def initialize(config, algod, indexer = nil)
        @config = config
        @algod = algod
        @indexer = indexer
        @event_emitter = AsyncEventEmitter.new
        @running = false
        @stop_signal = Concurrent::Event.new
        @mutex = Mutex.new
        @watermark = initialize_watermark
      end

      def on(filter_name, &)
        raise ArgumentError, "Block required" unless block_given?

        @event_emitter.on("transaction:#{filter_name}", &)
      end

      def on_batch(filter_name, &)
        raise ArgumentError, "Block required" unless block_given?

        @event_emitter.on("batch:#{filter_name}", &)
      end

      def on_before_poll(&)
        raise ArgumentError, "Block required" unless block_given?

        @event_emitter.on("before_poll", &)
      end

      def on_poll(&)
        raise ArgumentError, "Block required" unless block_given?

        @event_emitter.on("poll", &)
      end

      def on_error(&)
        raise ArgumentError, "Block required" unless block_given?

        @event_emitter.on("error", &)
      end

      def poll_once
        current_round = get_current_round
        starting_watermark = @watermark

        Algokit::Subscriber.logger.info("Polling: watermark=#{@watermark}, current=#{current_round}")

        @event_emitter.emit("before_poll", @watermark, current_round)

        result = Subscriptions.get_subscribed_transactions(
          config: @config,
          watermark: @watermark,
          current_round: current_round,
          algod: @algod,
          indexer: @indexer
        )

        emit_transactions(result)

        @watermark = result.new_watermark
        persist_watermark(@watermark)

        @event_emitter.emit("poll", result)

        Algokit::Subscriber.logger.info(
          "Poll complete: synced #{result.synced_round_range.length} rounds, " \
          "watermark: #{starting_watermark} -> #{@watermark}"
        )

        result
      rescue StandardError => e
        Algokit::Subscriber.logger.error("Poll error: #{e.message}")
        Algokit::Subscriber.logger.error(e.backtrace.join("\n"))
        @event_emitter.emit("error", e)
        raise
      end

      def start(inspect_proc = nil, suppress_log: false)
        @mutex.synchronize do
          raise "Subscriber is already running" if @running

          @running = true
          @stop_signal.reset
        end

        Algokit::Subscriber.logger.info("Starting subscriber...") unless suppress_log

        poll_loop(inspect_proc, suppress_log)
      ensure
        @mutex.synchronize { @running = false }
      end

      def stop(reason = nil)
        @mutex.synchronize do
          return unless @running

          Algokit::Subscriber.logger.info("Stopping subscriber: #{reason || "manual stop"}")
          @stop_signal.set
        end
      end

      def running?
        @mutex.synchronize { @running }
      end

      private

      def initialize_watermark
        if @config.watermark_persistence
          @config.watermark_persistence.get_watermark
        else
          0
        end
      end

      def persist_watermark(watermark)
        return unless @config.watermark_persistence

        @config.watermark_persistence.set_watermark(watermark)
      end

      def get_current_round
        status_data = @algod.status
        status = Models::Status.new(status_data)
        status.last_round
      end

      def poll_loop(inspect_proc, suppress_log)
        loop do
          break if @stop_signal.set?

          begin
            result = poll_once

            inspect_proc&.call(result)

            if result.synced_round_range.empty?
              sleep_or_wait_for_block(result, suppress_log)
            else
              sleep_between_polls(suppress_log)
            end
          rescue StandardError => e
            Algokit::Subscriber.logger.error("Poll loop error: #{e.message}")
            @event_emitter.emit("error", e)

            break if @stop_signal.set?

            sleep_on_error
          end
        end

        Algokit::Subscriber.logger.info("Subscriber stopped") unless suppress_log
      end

      def emit_transactions(result)
        result.subscribed_transactions.each do |filter_result|
          filter_name = filter_result.filter_name
          transactions = filter_result.transactions

          @event_emitter.emit("batch:#{filter_name}", transactions) if transactions.any?

          transactions.each do |transaction|
            @event_emitter.emit("transaction:#{filter_name}", transaction)
          end
        end
      end

      def sleep_or_wait_for_block(result, suppress_log)
        if @config.wait_for_block_when_at_tip && result.current_round == @watermark
          Algokit::Subscriber.logger.debug("At tip, waiting for next block...") unless suppress_log
          wait_for_next_block(result.current_round)
        else
          sleep_between_polls(suppress_log)
        end
      end

      def wait_for_next_block(current_round)
        return if @stop_signal.set?

        begin
          timeout = 60
          start_time = Time.now

          loop do
            break if @stop_signal.set?
            break if Time.now - start_time > timeout

            @algod.status_after_block(current_round)
            break
          rescue StandardError => e
            Algokit::Subscriber.logger.debug("Wait for block failed: #{e.message}")
            Utils.sleep_with_cancellation(1, @stop_signal)
          end
        rescue StandardError => e
          Algokit::Subscriber.logger.error("Wait for block error: #{e.message}")
          sleep_between_polls(true)
        end
      end

      def sleep_between_polls(suppress_log)
        return if @stop_signal.set?

        frequency = @config.frequency_in_seconds
        Algokit::Subscriber.logger.debug("Sleeping for #{frequency}s...") unless suppress_log
        Utils.sleep_with_cancellation(frequency, @stop_signal)
      end

      def sleep_on_error
        return if @stop_signal.set?

        Utils.sleep_with_cancellation(5, @stop_signal)
      end
    end
  end
end
