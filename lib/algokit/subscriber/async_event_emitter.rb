# frozen_string_literal: true

require "concurrent"

module Algokit
  module Subscriber
    class AsyncEventEmitter
      def initialize
        @listeners = Hash.new { |h, k| h[k] = [] }
        @mutex = Mutex.new
      end

      def on(event_name, &handler)
        @mutex.synchronize do
          @listeners[event_name] << handler
        end
        handler
      end

      def off(event_name, handler = nil)
        @mutex.synchronize do
          if handler
            @listeners[event_name].delete(handler)
          else
            @listeners[event_name].clear
          end
        end
      end

      def emit(event_name, *args)
        handlers = @mutex.synchronize { @listeners[event_name].dup }
        handlers.each do |handler|
          handler.call(*args)
        rescue StandardError => e
          Algokit::Subscriber.logger.error("Error in event handler for '#{event_name}': #{e.message}")
          Algokit::Subscriber.logger.error(e.backtrace.join("\n"))
        end
      end

      def emit_async(event_name, *args)
        handlers = @mutex.synchronize { @listeners[event_name].dup }
        handlers.map do |handler|
          Concurrent::Promise.execute do
            handler.call(*args)
          rescue StandardError => e
            Algokit::Subscriber.logger.error("Error in async event handler for '#{event_name}': #{e.message}")
            Algokit::Subscriber.logger.error(e.backtrace.join("\n"))
          end
        end
      end

      def listener_count(event_name)
        @mutex.synchronize { @listeners[event_name].length }
      end

      def clear_all
        @mutex.synchronize { @listeners.clear }
      end
    end
  end
end
