# frozen_string_literal: true

module Algokit
  module Subscriber
    # Base error class for all Algokit::Subscriber errors
    class Error < StandardError; end

    # Raised when a network error occurs during API communication
    class NetworkError < Error; end

    # Raised when an invalid round number is provided
    class InvalidRoundError < Error; end

    # Raised when an API returns an error response
    class ApiError < Error
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        super(message)
        @status = status
        @body = body
      end
    end

    # Raised when a configuration error occurs
    class ConfigurationError < Error; end
  end
end
