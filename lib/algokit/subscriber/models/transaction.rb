# frozen_string_literal: true

module Algokit
  module Subscriber
    module Models
      # Represents a transaction from the Algorand blockchain
      #
      # This is a simplified model that wraps the indexer transaction format
      # and provides convenient accessors for common transaction properties.
      class Transaction
        attr_reader :id, :type, :sender, :round, :timestamp, :note,
                    :fee, :first_valid, :last_valid, :genesis_id, :genesis_hash,
                    :group, :lease, :rekey_to, :signature,
                    :inner_txns, :logs, :intra_round_offset,
                    :created_asset_index, :created_application_index,
                    :closing_amount, :asset_closing_amount,
                    :global_state_delta, :local_state_delta,
                    :confirmed_round, :round_time

        # Payment transaction fields
        attr_reader :receiver, :amount, :close_remainder_to

        # Asset transfer fields
        attr_reader :asset_id, :asset_amount, :asset_sender,
                    :asset_receiver, :asset_close_to

        # Asset config fields
        attr_reader :asset_params

        # Application call fields
        attr_reader :application_id, :application_args, :accounts,
                    :foreign_apps, :foreign_assets, :approval_program,
                    :clear_program, :global_state_schema, :local_state_schema,
                    :extra_program_pages, :on_completion

        # Key registration fields
        attr_reader :vote_key, :selection_key, :vote_first, :vote_last,
                    :vote_key_dilution, :non_participation, :state_proof_key

        # @param data [Hash] Raw transaction data from indexer or transformed algod data
        def initialize(data)
          @id = data["id"]
          @type = data["tx-type"]
          @sender = data["sender"]
          @round = data["confirmed-round"]
          @timestamp = data["round-time"]
          @confirmed_round = data["confirmed-round"]
          @round_time = data["round-time"]
          @intra_round_offset = data["intra-round-offset"]

          # Transaction fields
          @fee = data["fee"]
          @first_valid = data["first-valid"]
          @last_valid = data["last-valid"]
          @genesis_id = data["genesis-id"]
          @genesis_hash = data["genesis-hash"]
          @group = data["group"]
          @lease = data["lease"]
          @note = data["note"]
          @rekey_to = data["rekey-to"]

          # Signature
          @signature = data["signature"]

          # Created indices
          @created_asset_index = data["created-asset-index"]
          @created_application_index = data["created-application-index"]

          # Closing amounts
          @closing_amount = data["closing-amount"]
          @asset_closing_amount = data["asset-closing-amount"]

          # State deltas
          @global_state_delta = data["global-state-delta"]
          @local_state_delta = data["local-state-delta"]

          # Logs and inner transactions
          @logs = data["logs"]
          @inner_txns = parse_inner_txns(data["inner-txns"])

          # Parse type-specific fields
          parse_payment_fields(data["payment-transaction"]) if data["payment-transaction"]
          parse_asset_transfer_fields(data["asset-transfer-transaction"]) if data["asset-transfer-transaction"]
          parse_asset_config_fields(data["asset-config-transaction"]) if data["asset-config-transaction"]
          parse_application_fields(data["application-transaction"]) if data["application-transaction"]
          parse_keyreg_fields(data["keyreg-transaction"]) if data["keyreg-transaction"]
        end

        # Check if this is a payment transaction
        # @return [Boolean]
        def payment?
          @type == "pay"
        end

        # Check if this is an asset transfer
        # @return [Boolean]
        def asset_transfer?
          @type == "axfer"
        end

        # Check if this is an asset configuration
        # @return [Boolean]
        def asset_config?
          @type == "acfg"
        end

        # Check if this is an application call
        # @return [Boolean]
        def application_call?
          @type == "appl"
        end

        # Check if this is a key registration
        # @return [Boolean]
        def key_registration?
          @type == "keyreg"
        end

        # Check if this created an asset
        # @return [Boolean]
        def created_asset?
          !@created_asset_index.nil?
        end

        # Check if this created an application
        # @return [Boolean]
        def created_application?
          !@created_application_index.nil?
        end

        # Get the note as a UTF-8 string
        # @return [String, nil]
        def note_text
          return nil unless @note

          # Note is base64 encoded in the API response
          require "base64"
          Base64.decode64(@note)
        rescue StandardError
          nil
        end

        # Convert to hash representation
        # @return [Hash]
        def to_h
          {
            id: @id,
            type: @type,
            sender: @sender,
            round: @round,
            timestamp: @timestamp,
            fee: @fee,
            note: @note,
            receiver: @receiver,
            amount: @amount,
            asset_id: @asset_id,
            asset_amount: @asset_amount,
            application_id: @application_id,
            created_asset_index: @created_asset_index,
            created_application_index: @created_application_index,
            inner_txns_count: @inner_txns&.length || 0,
            logs_count: @logs&.length || 0
          }.compact
        end

        private

        def parse_inner_txns(data)
          return nil unless data.is_a?(Array)

          data.map { |txn| Transaction.new(txn) }
        end

        def parse_payment_fields(data)
          @receiver = data["receiver"]
          @amount = data["amount"]
          @close_remainder_to = data["close-remainder-to"]
        end

        def parse_asset_transfer_fields(data)
          @asset_id = data["asset-id"]
          @asset_amount = data["amount"]
          @asset_sender = data["sender"]
          @asset_receiver = data["receiver"]
          @asset_close_to = data["close-to"]
        end

        def parse_asset_config_fields(data)
          @asset_id = data["asset-id"]
          @asset_params = data["params"]
        end

        def parse_application_fields(data)
          @application_id = data["application-id"]
          @application_args = data["application-args"]
          @accounts = data["accounts"]
          @foreign_apps = data["foreign-apps"]
          @foreign_assets = data["foreign-assets"]
          @approval_program = data["approval-program"]
          @clear_program = data["clear-state-program"]
          @global_state_schema = data["global-state-schema"]
          @local_state_schema = data["local-state-schema"]
          @extra_program_pages = data["extra-program-pages"]
          @on_completion = data["on-completion"]
        end

        def parse_keyreg_fields(data)
          @vote_key = data["vote-key"]
          @selection_key = data["selection-key"]
          @vote_first = data["vote-first-valid"]
          @vote_last = data["vote-last-valid"]
          @vote_key_dilution = data["vote-key-dilution"]
          @non_participation = data["non-participation"]
          @state_proof_key = data["state-proof-key"]
        end
      end
    end
  end
end
