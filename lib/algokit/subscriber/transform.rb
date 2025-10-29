# frozen_string_literal: true

require "base64"
require "digest"

module Algokit
  module Subscriber
    module Transform
      module_function

      def algod_transaction_to_indexer(algod_txn, block_metadata, parent_offset: nil)
        txn = algod_txn["txn"]
        signed_txn = algod_txn

        result = {
          "id" => signed_txn["txn"]["tx-id"] || calculate_transaction_id(signed_txn),
          "tx-type" => txn["type"],
          "sender" => txn["snd"],
          "fee" => txn["fee"],
          "first-valid" => txn["fv"],
          "last-valid" => txn["lv"],
          "round-time" => block_metadata.timestamp,
          "confirmed-round" => block_metadata.round,
          "genesis-id" => block_metadata.genesis_id,
          "genesis-hash" => block_metadata.genesis_hash
        }

        result["note"] = txn["note"] if txn["note"]
        result["group"] = txn["grp"] if txn["grp"]
        result["lease"] = txn["lx"] if txn["lx"]
        result["rekey-to"] = txn["rekey"] if txn["rekey"]

        result["intra-round-offset"] = if parent_offset
                                         parent_offset
                                       else
                                         signed_txn["hgi"] ? signed_txn["hgi"] + 1 : 0
                                       end

        case txn["type"]
        when "pay"
          result["payment-transaction"] = {
            "receiver" => txn["rcv"],
            "amount" => txn["amt"]
          }
          result["payment-transaction"]["close-amount"] = txn["camt"] if txn["camt"]
          result["payment-transaction"]["close-remainder-to"] = txn["close"] if txn["close"]

        when "axfer"
          result["asset-transfer-transaction"] = {
            "asset-id" => txn["xaid"],
            "amount" => txn["aamt"],
            "receiver" => txn["arcv"]
          }
          result["asset-transfer-transaction"]["sender"] = txn["asnd"] if txn["asnd"]
          result["asset-transfer-transaction"]["close-to"] = txn["aclose"] if txn["aclose"]
          result["asset-transfer-transaction"]["close-amount"] = txn["aca"] if txn["aca"]

        when "acfg"
          result["asset-config-transaction"] = {}
          result["asset-config-transaction"]["asset-id"] = txn["caid"] if txn["caid"]
          result["created-asset-index"] = signed_txn["caid"] if signed_txn["caid"]

          if txn["apar"]
            result["asset-config-transaction"]["params"] = {
              "total" => txn["apar"]["t"],
              "decimals" => txn["apar"]["dc"],
              "default-frozen" => txn["apar"]["df"]
            }
            result["asset-config-transaction"]["params"]["unit-name"] = txn["apar"]["un"] if txn["apar"]["un"]
            result["asset-config-transaction"]["params"]["name"] = txn["apar"]["an"] if txn["apar"]["an"]
            result["asset-config-transaction"]["params"]["url"] = txn["apar"]["au"] if txn["apar"]["au"]
            result["asset-config-transaction"]["params"]["metadata-hash"] = txn["apar"]["am"] if txn["apar"]["am"]
            result["asset-config-transaction"]["params"]["manager"] = txn["apar"]["m"] if txn["apar"]["m"]
            result["asset-config-transaction"]["params"]["reserve"] = txn["apar"]["r"] if txn["apar"]["r"]
            result["asset-config-transaction"]["params"]["freeze"] = txn["apar"]["f"] if txn["apar"]["f"]
            result["asset-config-transaction"]["params"]["clawback"] = txn["apar"]["c"] if txn["apar"]["c"]
          end

        when "afrz"
          result["asset-freeze-transaction"] = {
            "asset-id" => txn["faid"],
            "address" => txn["fadd"],
            "new-freeze-status" => txn["afrz"]
          }

        when "appl"
          result["application-transaction"] = {
            "application-id" => txn["apid"] || 0,
            "on-completion" => txn["apan"] || "noop"
          }
          result["application-transaction"]["application-args"] = txn["apaa"] if txn["apaa"]
          result["application-transaction"]["accounts"] = txn["apat"] if txn["apat"]
          result["application-transaction"]["foreign-apps"] = txn["apfa"] if txn["apfa"]
          result["application-transaction"]["foreign-assets"] = txn["apas"] if txn["apas"]
          result["application-transaction"]["approval-program"] = txn["apap"] if txn["apap"]
          result["application-transaction"]["clear-state-program"] = txn["apsu"] if txn["apsu"]
          result["application-transaction"]["global-state-schema"] = txn["apgs"] if txn["apgs"]
          result["application-transaction"]["local-state-schema"] = txn["apls"] if txn["apls"]
          result["application-transaction"]["extra-program-pages"] = txn["apep"] if txn["apep"]

          result["created-application-index"] = signed_txn["apid"] if signed_txn["apid"]
          result["logs"] = signed_txn["dt"]["lg"] if signed_txn.dig("dt", "lg")
          result["global-state-delta"] = signed_txn.dig("dt", "gd") if signed_txn.dig("dt", "gd")
          result["local-state-delta"] = signed_txn.dig("dt", "ld") if signed_txn.dig("dt", "ld")

        when "keyreg"
          result["keyreg-transaction"] = {}
          result["keyreg-transaction"]["vote-key"] = txn["votekey"] if txn["votekey"]
          result["keyreg-transaction"]["selection-key"] = txn["selkey"] if txn["selkey"]
          result["keyreg-transaction"]["vote-first-valid"] = txn["votefst"] if txn["votefst"]
          result["keyreg-transaction"]["vote-last-valid"] = txn["votelst"] if txn["votelst"]
          result["keyreg-transaction"]["vote-key-dilution"] = txn["votekd"] if txn["votekd"]
          result["keyreg-transaction"]["non-participation"] = txn["nonpart"] if txn["nonpart"]
        end

        if signed_txn.dig("dt", "itx")
          parent_intra = result["intra-round-offset"]
          result["inner-txns"] = signed_txn["dt"]["itx"].map.with_index do |inner, idx|
            inner_offset = parent_intra + idx + 1
            algod_transaction_to_indexer(inner, block_metadata, parent_offset: inner_offset)
          end
        end

        result.compact
      end

      def extract_balance_changes(transaction)
        changes = {}

        sender = transaction["sender"]
        fee = transaction["fee"] || 0

        add_balance_change(changes, sender, 0, -fee, Types::BalanceChangeRole::SENDER)

        case transaction["tx-type"]
        when "pay"
          receiver = transaction.dig("payment-transaction", "receiver")
          amount = transaction.dig("payment-transaction", "amount") || 0
          close_to = transaction.dig("payment-transaction", "close-remainder-to")
          close_amount = transaction.dig("payment-transaction", "close-amount") || 0

          add_balance_change(changes, sender, 0, -amount, Types::BalanceChangeRole::SENDER)
          add_balance_change(changes, receiver, 0, amount, Types::BalanceChangeRole::RECEIVER)

          if close_to && close_amount.positive?
            add_balance_change(changes, sender, 0, -close_amount, Types::BalanceChangeRole::SENDER)
            add_balance_change(changes, close_to, 0, close_amount, Types::BalanceChangeRole::CLOSE_TO)
          end

        when "axfer"
          asset_id = transaction.dig("asset-transfer-transaction", "asset-id")
          amount = transaction.dig("asset-transfer-transaction", "amount") || 0
          receiver = transaction.dig("asset-transfer-transaction", "receiver")
          asset_sender = transaction.dig("asset-transfer-transaction", "sender")
          close_to = transaction.dig("asset-transfer-transaction", "close-to")
          close_amount = transaction.dig("asset-transfer-transaction", "close-amount") || 0

          actual_sender = asset_sender || sender

          add_balance_change(changes, actual_sender, asset_id, -amount, Types::BalanceChangeRole::SENDER)
          add_balance_change(changes, receiver, asset_id, amount, Types::BalanceChangeRole::RECEIVER)

          if close_to && close_amount.positive?
            add_balance_change(changes, actual_sender, asset_id, -close_amount, Types::BalanceChangeRole::SENDER)
            add_balance_change(changes, close_to, asset_id, close_amount, Types::BalanceChangeRole::CLOSE_TO)
          end

        when "acfg"
          created_asset_id = transaction["created-asset-index"]
          if created_asset_id
            params = transaction.dig("asset-config-transaction", "params")
            total = params ? params["total"] : 0
            add_balance_change(changes, sender, created_asset_id, total, Types::BalanceChangeRole::ASSET_CREATOR)
          end

          destroyed_asset_id = transaction.dig("asset-config-transaction", "asset-id")
          if destroyed_asset_id && transaction.dig("asset-config-transaction", "params").nil?
            add_balance_change(changes, sender, destroyed_asset_id, 0, Types::BalanceChangeRole::ASSET_DESTROYER)
          end
        end

        transaction["inner-txns"]&.each do |inner|
          inner_changes = extract_balance_changes(inner)
          merge_balance_changes(changes, inner_changes)
        end

        changes.values
      end

      def parse_arc28_events(logs, arc28_event_groups)
        return [] if logs.nil? || logs.empty? || arc28_event_groups.empty?

        events = []
        event_definitions_by_selector = build_event_selector_map(arc28_event_groups)

        logs.each do |log|
          decoded_log = Base64.decode64(log)
          next if decoded_log.length < 4

          selector = decoded_log[0..3]
          event_def = event_definitions_by_selector[selector]
          next unless event_def

          begin
            args = decode_event_args(decoded_log[4..], event_def[:definition].args)
            events << Types::Arc28Event.new(
              group_name: event_def[:group_name],
              event_name: event_def[:definition].name,
              event_signature: event_def[:definition].signature,
              args: args
            )
          rescue StandardError => e
            warn "Failed to decode ARC-28 event: #{e.message}"
          end
        end

        events
      end

      private_class_method def calculate_transaction_id(signed_txn)
        txn_data = signed_txn["txn"].to_json
        Digest::SHA2.hexdigest(txn_data)[0..51]
      end

      private_class_method def add_balance_change(changes, address, asset_id, amount, role)
        return if amount.zero? && role != Types::BalanceChangeRole::ASSET_DESTROYER

        key = "#{address}:#{asset_id}"
        changes[key] ||= Types::BalanceChange.new(address: address, asset_id: asset_id, amount: 0, roles: [])
        changes[key].amount += amount
        changes[key].roles << role unless changes[key].roles.include?(role)
      end

      private_class_method def merge_balance_changes(target, source)
        source.each do |change|
          key = "#{change.address}:#{change.asset_id}"
          if target[key]
            target[key].amount += change.amount
            change.roles.each do |role|
              target[key].roles << role unless target[key].roles.include?(role)
            end
          else
            target[key] = change
          end
        end
      end

      private_class_method def build_event_selector_map(arc28_event_groups)
        map = {}
        arc28_event_groups.each do |group|
          group.events.each do |event_def|
            map[event_def.selector] = {
              group_name: group.group_name,
              definition: event_def
            }
          end
        end
        map
      end

      private_class_method def decode_event_args(data, arg_definitions)
        offset = 0
        args = {}

        arg_definitions.each do |arg_def|
          value, bytes_read = decode_abi_value(arg_def.type, data[offset..])
          args[arg_def.name] = value
          offset += bytes_read
        end

        args
      end

      private_class_method def decode_abi_value(type, data)
        case type
        when "uint64"
          value = data[0..7].unpack1("Q>")
          [value, 8]
        when "uint32"
          value = data[0..3].unpack1("N")
          [value, 4]
        when "byte"
          [data[0], 1]
        when "address"
          [Base64.strict_encode64(data[0..31]), 32]
        when "string"
          length = data[0..1].unpack1("n")
          value = data[2..(length + 1)]
          [value, length + 2]
        when /^byte\[(\d+)\]$/
          length = Regexp.last_match(1).to_i
          [Base64.strict_encode64(data[0..(length - 1)]), length]
        else
          [data, data.length]
        end
      end
    end
  end
end
