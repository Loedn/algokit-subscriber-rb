# frozen_string_literal: true

module Algokit
  module Subscriber
    module Types
      module BalanceChangeRole
        SENDER = "Sender"
        RECEIVER = "Receiver"
        CLOSE_TO = "CloseTo"
        ASSET_CREATOR = "AssetCreator"
        ASSET_DESTROYER = "AssetDestroyer"
      end

      class BalanceChange
        attr_accessor :address, :asset_id, :amount, :roles

        def initialize(address:, asset_id: 0, amount: 0, roles: [])
          @address = address
          @asset_id = asset_id
          @amount = amount
          @roles = roles
        end

        def algo_change?
          @asset_id.zero?
        end

        def asset_change?
          !@asset_id.zero?
        end

        def to_h
          {
            address: @address,
            asset_id: @asset_id,
            amount: @amount,
            roles: @roles
          }
        end

        def ==(other)
          return false unless other.is_a?(BalanceChange)

          @address == other.address &&
            @asset_id == other.asset_id &&
            @amount == other.amount &&
            @roles.sort == other.roles.sort
        end
      end
    end
  end
end
