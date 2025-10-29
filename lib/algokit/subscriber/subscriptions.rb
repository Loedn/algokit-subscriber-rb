# frozen_string_literal: true

module Algokit
  module Subscriber
    class Subscriptions
      class << self
        def get_subscribed_transactions(config:, watermark:, current_round:, algod:, indexer: nil)
          starting_watermark = watermark

          if watermark >= current_round
            return Types::SubscriptionResult.new(
              starting_watermark: starting_watermark,
              new_watermark: watermark,
              synced_round_range: [],
              current_round: current_round,
              subscribed_transactions: []
            )
          end

          sync_from = watermark + 1
          sync_to = [watermark + config.max_rounds_to_sync, current_round].min

          synced_rounds = Utils.range(sync_from, sync_to)
          transactions = []

          rounds_behind = current_round - watermark
          should_use_indexer = indexer &&
                               rounds_behind > config.max_rounds_to_sync &&
                               config.sync_behaviour == Types::SyncBehaviour::CATCHUP_WITH_INDEXER

          if should_use_indexer && rounds_behind > 1
            indexer_sync_to = [watermark + config.max_indexer_rounds_to_sync, current_round].min
            synced_rounds = Utils.range(sync_from, indexer_sync_to)
            transactions = sync_with_indexer(
              indexer: indexer,
              filters: config.filters,
              min_round: sync_from,
              max_round: indexer_sync_to,
              arc28_events: config.arc28_events
            )
            sync_to = indexer_sync_to
          else
            transactions = sync_with_algod(
              algod: algod,
              filters: config.filters,
              rounds: synced_rounds,
              arc28_events: config.arc28_events
            )
          end

          filtered_transactions = apply_filters(transactions, config.filters, config.arc28_events)

          Types::SubscriptionResult.new(
            starting_watermark: starting_watermark,
            new_watermark: sync_to,
            synced_round_range: synced_rounds,
            current_round: current_round,
            subscribed_transactions: filtered_transactions
          )
        end

        private

        def sync_with_indexer(indexer:, filters:, min_round:, max_round:, arc28_events:)
          all_transactions = []

          filters.each do |named_filter|
            pre_filter_params = indexer_pre_filter(named_filter.filter)
            params = pre_filter_params.merge(
              min_round: min_round,
              max_round: max_round,
              limit: 1000
            )

            loop do
              result = indexer.search_transactions(params)
              transactions = result["transactions"] || []

              all_transactions.concat(transactions.map do |txn|
                {
                  filter_name: named_filter.name,
                  transaction: txn
                }
              end)

              break unless result["next-token"]

              params[:next] = result["next-token"]
            end
          end

          all_transactions
        end

        def sync_with_algod(algod:, filters:, rounds:, arc28_events:)
          return [] if rounds.empty?

          all_transactions = []
          blocks = fetch_blocks_in_parallel(algod, rounds)

          blocks.each do |block_data|
            next unless block_data["block"]

            block = Models::Block.new(block_data["block"])
            block_metadata = Types::BlockMetadata.new(
              round: block.round,
              timestamp: block.timestamp,
              genesis_id: block.genesis_id,
              genesis_hash: block.genesis_hash
            )

            transactions = extract_transactions_from_block(
              block_data["block"],
              block_metadata,
              arc28_events
            )

            transactions.each do |txn|
              filters.each do |named_filter|
                next unless transaction_matches_filter?(txn, named_filter.filter, arc28_events)

                all_transactions << {
                  filter_name: named_filter.name,
                  transaction: txn
                }
              end
            end
          end

          all_transactions
        end

        def fetch_blocks_in_parallel(algod, rounds)
          chunks = Utils.chunk_array(rounds, 30)
          all_blocks = []

          chunks.each do |chunk|
            promises = chunk.map do |round|
              Concurrent::Promise.execute do
                algod.block(round)
              rescue StandardError => e
                Algokit::Subscriber.logger.error("Failed to fetch block #{round}: #{e.message}")
                nil
              end
            end

            blocks = promises.map(&:value!).compact
            all_blocks.concat(blocks)
          end

          all_blocks
        end

        def extract_transactions_from_block(block, block_metadata, arc28_events)
          return [] unless block["txns"]

          transactions = []

          block["txns"].each do |signed_txn|
            indexer_txn = Transform.algod_transaction_to_indexer(signed_txn, block_metadata)

            if indexer_txn["logs"] && !arc28_events.empty?
              indexer_txn["arc28-events"] = Transform.parse_arc28_events(
                indexer_txn["logs"],
                arc28_events
              )
            end

            indexer_txn["balance-changes"] = Transform.extract_balance_changes(indexer_txn)

            transactions << indexer_txn

            transactions.concat(flatten_inner_transactions(indexer_txn["inner-txns"])) if indexer_txn["inner-txns"]
          end

          transactions
        end

        def flatten_inner_transactions(inner_txns)
          flat = []
          inner_txns.each do |inner|
            flat << inner
            flat.concat(flatten_inner_transactions(inner["inner-txns"])) if inner["inner-txns"]
          end
          flat
        end

        def apply_filters(transactions, filters, arc28_events)
          result = {}

          transactions.each do |txn_data|
            filter_name = txn_data[:filter_name]
            txn = txn_data[:transaction]

            named_filter = filters.find { |f| f.name == filter_name }
            next unless named_filter

            next unless indexer_post_filter_matches?(txn, named_filter.filter, arc28_events)

            result[filter_name] ||= Types::TransactionSubscriptionResult.new(
              filter_name: filter_name,
              transactions: []
            )

            mapped_txn = named_filter.mapper ? named_filter.mapper.call(txn) : txn
            result[filter_name].transactions << mapped_txn
          end

          result.values
        end

        def indexer_pre_filter(filter)
          params = {}

          params[:tx_type] = filter.type if filter.type
          params[:address] = filter.sender if filter.sender
          params[:address] = filter.receiver if filter.receiver && !filter.sender
          params[:note_prefix] = filter.note_prefix if filter.note_prefix
          params[:application_id] = filter.app_id if filter.app_id
          params[:asset_id] = filter.asset_id if filter.asset_id
          params[:currency_greater_than] = filter.min_amount if filter.min_amount
          params[:currency_less_than] = filter.max_amount if filter.max_amount

          params
        end

        def indexer_post_filter_matches?(transaction, filter, arc28_events)
          return false unless filter.matches?(transaction)

          if filter.balance_changes
            balance_changes = transaction["balance-changes"] || []
            return false unless balance_change_matches?(balance_changes, filter.balance_changes)
          end

          if filter.arc28_events && !arc28_events.empty?
            events = transaction["arc28-events"] || []
            return false unless arc28_event_matches?(events, filter.arc28_events)
          end

          true
        end

        def transaction_matches_filter?(transaction, filter, arc28_events)
          return false unless filter.matches?(transaction)

          if filter.balance_changes
            balance_changes = transaction["balance-changes"] || []
            return false unless balance_change_matches?(balance_changes, filter.balance_changes)
          end

          if filter.arc28_events && !arc28_events.empty?
            events = transaction["arc28-events"] || []
            return false unless arc28_event_matches?(events, filter.arc28_events)
          end

          true
        end

        def balance_change_matches?(balance_changes, expected_changes)
          return true if expected_changes.nil? || expected_changes.empty?

          expected_changes.all? do |expected|
            balance_changes.any? do |change|
              matches = true
              matches &&= change.address == expected[:address] if expected[:address]
              matches &&= change.asset_id == expected[:asset_id] if expected[:asset_id]
              matches &&= change.amount >= expected[:min_amount] if expected[:min_amount]
              matches &&= change.amount <= expected[:max_amount] if expected[:max_amount]
              matches &&= expected[:roles].intersect?(change.roles) if expected[:roles]
              matches
            end
          end
        end

        def arc28_event_matches?(events, expected_events)
          return true if expected_events.nil? || expected_events.empty?

          expected_events.all? do |expected|
            events.any? do |event|
              matches = true
              matches &&= event.group_name == expected[:group_name] if expected[:group_name]
              matches &&= event.event_name == expected[:event_name] if expected[:event_name]

              expected[:args]&.each do |key, value|
                matches &&= event.args[key] == value
              end

              matches
            end
          end
        end
      end
    end
  end
end
