# frozen_string_literal: true

module Algokit
  module Subscriber
    module Models
      # Represents the status of an Algorand node
      #
      # Contains information about the current state of the blockchain including
      # the last round, catchup status, and version information.
      class Status
        attr_reader :last_round, :time_since_last_round, :catchup_time,
                    :last_version, :next_version, :next_version_round,
                    :next_version_supported, :stopped_at_unsupported_round

        # @param data [Hash] Raw status data from algod API
        def initialize(data)
          @last_round = data["last-round"]
          @time_since_last_round = data["time-since-last-round"]
          @catchup_time = data["catchup-time"]
          @last_version = data["last-version"]
          @next_version = data["next-version"]
          @next_version_round = data["next-version-round"]
          @next_version_supported = data["next-version-supported"]
          @stopped_at_unsupported_round = data["stopped-at-unsupported-round"]
        end

        # Convert to hash representation
        # @return [Hash]
        def to_h
          {
            last_round: @last_round,
            time_since_last_round: @time_since_last_round,
            catchup_time: @catchup_time,
            last_version: @last_version,
            next_version: @next_version,
            next_version_round: @next_version_round,
            next_version_supported: @next_version_supported,
            stopped_at_unsupported_round: @stopped_at_unsupported_round
          }
        end

        # Check if node is caught up
        # @return [Boolean]
        def caught_up?
          @catchup_time.zero?
        end

        # Get time since last round in seconds
        # @return [Float]
        def time_since_last_round_seconds
          @time_since_last_round / 1_000_000_000.0 if @time_since_last_round
        end
      end
    end
  end
end
