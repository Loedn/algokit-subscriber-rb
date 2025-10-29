# frozen_string_literal: true

module Algokit
  module Subscriber
    module Types
      class TransactionFilter
        attr_accessor :type, :sender, :receiver, :note_prefix, :app_id, :asset_id,
                      :min_amount, :max_amount, :app_create, :asset_create,
                      :app_on_complete, :method_signature, :balance_changes,
                      :arc28_events, :custom_filter

        def initialize(**options)
          @type = options[:type]
          @sender = options[:sender]
          @receiver = options[:receiver]
          @note_prefix = options[:note_prefix]
          @app_id = options[:app_id]
          @asset_id = options[:asset_id]
          @min_amount = options[:min_amount]
          @max_amount = options[:max_amount]
          @app_create = options[:app_create]
          @asset_create = options[:asset_create]
          @app_on_complete = options[:app_on_complete]
          @method_signature = options[:method_signature]
          @balance_changes = options[:balance_changes]
          @arc28_events = options[:arc28_events]
          @custom_filter = options[:custom_filter]
        end

        def matches?(transaction)
          return false unless type_matches?(transaction)
          return false unless sender_matches?(transaction)
          return false unless receiver_matches?(transaction)
          return false unless note_prefix_matches?(transaction)
          return false unless app_id_matches?(transaction)
          return false unless asset_id_matches?(transaction)
          return false unless amount_matches?(transaction)
          return false unless app_create_matches?(transaction)
          return false unless asset_create_matches?(transaction)
          return false unless app_on_complete_matches?(transaction)
          return false unless method_signature_matches?(transaction)
          return false unless custom_filter_matches?(transaction)

          true
        end

        private

        def type_matches?(transaction)
          return true if @type.nil?

          transaction["tx-type"] == @type
        end

        def sender_matches?(transaction)
          return true if @sender.nil?

          transaction.dig("txn", "snd") == @sender || transaction["sender"] == @sender
        end

        def receiver_matches?(transaction)
          return true if @receiver.nil?

          rcv = transaction.dig("txn", "rcv") || transaction.dig("payment-transaction", "receiver")
          rcv == @receiver
        end

        def note_prefix_matches?(transaction)
          return true if @note_prefix.nil?

          note = transaction.dig("txn", "note") || transaction["note"]
          return false if note.nil?

          note.start_with?(@note_prefix)
        end

        def app_id_matches?(transaction)
          return true if @app_id.nil?

          app_id = transaction.dig("txn", "apid") ||
                   transaction.dig("application-transaction", "application-id") ||
                   transaction["created-application-index"]
          app_id == @app_id
        end

        def asset_id_matches?(transaction)
          return true if @asset_id.nil?

          asset_id = transaction.dig("txn", "xaid") ||
                     transaction.dig("asset-transfer-transaction", "asset-id") ||
                     transaction.dig("asset-config-transaction", "asset-id") ||
                     transaction["created-asset-index"]
          asset_id == @asset_id
        end

        def amount_matches?(transaction)
          return true if @min_amount.nil? && @max_amount.nil?

          amount = transaction.dig("txn", "amt") ||
                   transaction.dig("payment-transaction", "amount") ||
                   transaction.dig("asset-transfer-transaction", "amount")
          return true if amount.nil?

          return false if @min_amount && amount < @min_amount
          return false if @max_amount && amount > @max_amount

          true
        end

        def app_create_matches?(transaction)
          return true if @app_create.nil?

          is_create = transaction["created-application-index"]&.positive? ||
                      (transaction.dig("txn", "apid").nil? && transaction["tx-type"] == "appl")
          is_create == @app_create
        end

        def asset_create_matches?(transaction)
          return true if @asset_create.nil?

          is_create = transaction["created-asset-index"]&.positive? ||
                      (transaction.dig("txn", "caid").nil? && transaction["tx-type"] == "acfg")
          is_create == @asset_create
        end

        def app_on_complete_matches?(transaction)
          return true if @app_on_complete.nil?

          on_complete = transaction.dig("txn", "apan") ||
                        transaction.dig("application-transaction", "on-completion")
          on_complete == @app_on_complete
        end

        def method_signature_matches?(transaction)
          return true if @method_signature.nil?

          app_args = transaction.dig("txn", "apaa") ||
                     transaction.dig("application-transaction", "application-args")
          return false if app_args.nil? || app_args.empty?

          method_selector = app_args.first[0..3]
          expected_selector = Digest::SHA2.digest(@method_signature)[0..3]
          method_selector == expected_selector
        end

        def custom_filter_matches?(transaction)
          return true if @custom_filter.nil?

          @custom_filter.call(transaction)
        end
      end

      class NamedTransactionFilter
        attr_accessor :name, :filter, :mapper

        def initialize(name:, filter:, mapper: nil)
          @name = name
          @filter = filter.is_a?(TransactionFilter) ? filter : TransactionFilter.new(**filter)
          @mapper = mapper
        end

        def apply(transaction)
          return nil unless @filter.matches?(transaction)

          @mapper ? @mapper.call(transaction) : transaction
        end
      end
    end
  end
end
