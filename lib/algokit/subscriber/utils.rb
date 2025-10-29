# frozen_string_literal: true

require "concurrent"

module Algokit
  module Subscriber
    module Utils
      module_function

      def chunk_array(array, size)
        return [] if array.empty? || size <= 0

        array.each_slice(size).to_a
      end

      def range(start, stop)
        return [] if start > stop

        (start..stop).to_a
      end

      def sleep_with_cancellation(duration, stop_signal)
        return if stop_signal&.set?

        if stop_signal
          stop_signal.wait(duration)
        else
          sleep(duration)
        end
      end

      def race(promise, stop_signal, timeout: nil)
        return promise.value! if stop_signal.nil? && timeout.nil?

        stop_promise = Concurrent::Promise.new do
          stop_signal&.wait
          :stopped
        end.execute

        timeout_promise = if timeout
                            Concurrent::Promise.new do
                              sleep(timeout)
                              :timeout
                            end.execute
                          end

        promises = [promise, stop_promise]
        promises << timeout_promise if timeout_promise

        result = Concurrent::Promise.zip(*promises).value!
        result.find { |r| r != :stopped && r != :timeout }
      end

      def get_blocks_bulk(rounds, algod, max_parallel: 30)
        return [] if rounds.empty?

        chunks = chunk_array(rounds, max_parallel)
        all_blocks = []

        chunks.each do |chunk|
          promises = chunk.map do |round|
            Concurrent::Promise.execute do
              algod.block(round)
            end
          end

          blocks = promises.map(&:value!)
          all_blocks.concat(blocks)
        end

        all_blocks
      end

      def method_signature_to_selector(signature)
        Digest::SHA2.digest(signature)[0..3]
      end

      def decode_app_args(app_args)
        return [] if app_args.nil? || app_args.empty?

        app_args.map { |arg| Base64.decode64(arg) }
      end

      def encode_app_args(app_args)
        return [] if app_args.nil? || app_args.empty?

        app_args.map { |arg| Base64.strict_encode64(arg) }
      end

      def decode_note(note)
        return nil if note.nil?

        Base64.decode64(note)
      end

      def encode_note(note)
        return nil if note.nil?

        Base64.strict_encode64(note)
      end
    end
  end
end
