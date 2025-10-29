# frozen_string_literal: true

module Algokit
  module Subscriber
    module Types
      module SyncBehaviour
        CATCHUP_WITH_INDEXER = "catchup-with-indexer"
        SYNC_OLDEST = "sync-oldest"
        SYNC_OLDEST_START_NOW = "sync-oldest-start-now"
        SKIP_SYNC_NEWEST = "skip-sync-newest"
        FAIL = "fail"
      end

      class BlockMetadata
        attr_accessor :round, :timestamp, :genesis_id, :genesis_hash

        def initialize(round:, timestamp:, genesis_id:, genesis_hash:)
          @round = round
          @timestamp = timestamp
          @genesis_id = genesis_id
          @genesis_hash = genesis_hash
        end
      end

      class WatermarkPersistence
        attr_accessor :get, :set

        def initialize(get:, set:)
          @get = get
          @set = set
        end

        def get_watermark
          @get.call
        end

        def set_watermark(watermark)
          @set.call(watermark)
        end
      end

      class SubscriptionConfig
        attr_accessor :filters, :arc28_events, :max_rounds_to_sync,
                      :max_indexer_rounds_to_sync, :sync_behaviour,
                      :frequency_in_seconds, :wait_for_block_when_at_tip,
                      :watermark_persistence

        def initialize(**options)
          @filters = parse_filters(options[:filters] || [])
          @arc28_events = parse_arc28_events(options[:arc28_events] || [])
          @max_rounds_to_sync = options[:max_rounds_to_sync] || 100
          @max_indexer_rounds_to_sync = options[:max_indexer_rounds_to_sync] || 1000
          @sync_behaviour = options[:sync_behaviour] || SyncBehaviour::CATCHUP_WITH_INDEXER
          @frequency_in_seconds = options[:frequency_in_seconds] || 1.0
          @wait_for_block_when_at_tip = options[:wait_for_block_when_at_tip].nil? || options[:wait_for_block_when_at_tip]
          @watermark_persistence = parse_watermark_persistence(options[:watermark_persistence])
        end

        def validate!
          raise ConfigurationError, "filters must be an array" unless @filters.is_a?(Array)
          raise ConfigurationError, "max_rounds_to_sync must be positive" if @max_rounds_to_sync <= 0
          raise ConfigurationError, "max_indexer_rounds_to_sync must be positive" if @max_indexer_rounds_to_sync <= 0
          raise ConfigurationError, "frequency_in_seconds must be positive" if @frequency_in_seconds <= 0

          valid_behaviours = [
            SyncBehaviour::CATCHUP_WITH_INDEXER,
            SyncBehaviour::SYNC_OLDEST,
            SyncBehaviour::SYNC_OLDEST_START_NOW,
            SyncBehaviour::SKIP_SYNC_NEWEST,
            SyncBehaviour::FAIL
          ]
          unless valid_behaviours.include?(@sync_behaviour)
            raise ConfigurationError, "sync_behaviour must be one of: #{valid_behaviours.join(", ")}"
          end

          true
        end

        private

        def parse_filters(filters)
          filters.map do |filter|
            if filter.is_a?(NamedTransactionFilter)
              filter
            elsif filter.is_a?(Hash)
              NamedTransactionFilter.new(**filter)
            else
              raise ConfigurationError, "Invalid filter: #{filter}"
            end
          end
        end

        def parse_arc28_events(events)
          events.map do |event|
            if event.is_a?(Arc28EventGroup)
              event
            elsif event.is_a?(Hash)
              Arc28EventGroup.new(**event)
            else
              raise ConfigurationError, "Invalid ARC-28 event: #{event}"
            end
          end
        end

        def parse_watermark_persistence(persistence)
          return nil if persistence.nil?

          if persistence.is_a?(WatermarkPersistence)
            persistence
          elsif persistence.is_a?(Hash)
            WatermarkPersistence.new(**persistence)
          else
            raise ConfigurationError, "Invalid watermark_persistence: #{persistence}"
          end
        end
      end

      class SubscriptionResult
        attr_accessor :starting_watermark, :new_watermark, :synced_round_range,
                      :current_round, :subscribed_transactions

        def initialize(starting_watermark:, new_watermark:, synced_round_range:,
                       current_round:, subscribed_transactions:)
          @starting_watermark = starting_watermark
          @new_watermark = new_watermark
          @synced_round_range = synced_round_range
          @current_round = current_round
          @subscribed_transactions = subscribed_transactions
        end

        def rounds_synced
          return 0 if @synced_round_range.nil? || @synced_round_range.empty?

          @synced_round_range.size
        end
      end

      class TransactionSubscriptionResult
        attr_accessor :filter_name, :transactions

        def initialize(filter_name:, transactions:)
          @filter_name = filter_name
          @transactions = transactions
        end
      end
    end
  end
end
