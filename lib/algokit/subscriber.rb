# frozen_string_literal: true

require "logger"
require_relative "subscriber/version"
require_relative "subscriber/errors"
require_relative "subscriber/client/algod_client"
require_relative "subscriber/client/indexer_client"
require_relative "subscriber/models/status"
require_relative "subscriber/models/block"
require_relative "subscriber/models/transaction"
require_relative "subscriber/types/balance_change"
require_relative "subscriber/types/arc28_event"
require_relative "subscriber/types/transaction_filter"
require_relative "subscriber/types/subscription"
require_relative "subscriber/transform"
require_relative "subscriber/utils"
require_relative "subscriber/subscriptions"
require_relative "subscriber/async_event_emitter"
require_relative "subscriber/algorand_subscriber"

module Algokit
  module Subscriber
    class << self
      # Configure the logger for the gem
      attr_writer :logger

      def logger
        @logger ||= Logger.new($stdout).tap do |log|
          log.level = Logger::INFO
        end
      end
    end
  end
end
