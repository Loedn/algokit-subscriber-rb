# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Algokit
  module Subscriber
    module Client
      # HTTP client for Algorand algod API
      #
      # Provides methods to interact with the Algorand daemon (algod) for:
      # - Getting current blockchain status
      # - Retrieving blocks
      # - Waiting for specific rounds (low-latency mode)
      #
      # @example
      #   algod = AlgodClient.new('https://testnet-api.algonode.cloud')
      #   status = algod.status
      #   block = algod.block(12345)
      class AlgodClient
        API_VERSION = "v2"
        DEFAULT_TIMEOUT = 30

        # @param server [String] The algod server URL
        # @param token [String, nil] Optional API token for authentication
        # @param headers [Hash] Optional additional headers
        # @param timeout [Integer] Request timeout in seconds (default: 30)
        def initialize(server, token: nil, headers: {}, timeout: DEFAULT_TIMEOUT)
          @server = server.sub(%r{/+$}, "") # Remove trailing slashes
          @token = token
          @headers = headers
          @timeout = timeout
        end

        # Get the current node status
        #
        # @return [Hash] Status information including last-round
        # @raise [ApiError] if the API returns an error
        # @raise [NetworkError] if a network error occurs
        #
        # @example
        #   status = algod.status
        #   puts "Current round: #{status['last-round']}"
        def status
          get("status")
        end

        # Get a specific block by round number
        #
        # @param round [Integer] The round number to retrieve
        # @return [Hash] Block data including transactions
        # @raise [InvalidRoundError] if the round number is invalid
        # @raise [ApiError] if the API returns an error
        # @raise [NetworkError] if a network error occurs
        #
        # @example
        #   block = algod.block(12345)
        #   puts "Block has #{block.dig('block', 'txns')&.length || 0} transactions"
        def block(round)
          raise InvalidRoundError, "Round must be a positive integer" unless round.is_a?(Integer) && round.positive?

          get("blocks/#{round}")
        rescue ApiError => e
          raise InvalidRoundError, "Block not found for round #{round}" if e.status == 404

          raise
        end

        # Wait for a block to appear after the specified round
        #
        # This method blocks until a new round is available, enabling low-latency
        # transaction processing when at the tip of the chain.
        #
        # @param round [Integer] The round number to wait after
        # @return [Hash] Status information when the next round is available
        # @raise [InvalidRoundError] if the round number is invalid
        # @raise [ApiError] if the API returns an error
        # @raise [NetworkError] if a network error occurs
        #
        # @example
        #   current = algod.status['last-round']
        #   result = algod.status_after_block(current)
        #   puts "New round available: #{result['last-round']}"
        def status_after_block(round)
          raise InvalidRoundError, "Round must be a non-negative integer" unless round.is_a?(Integer) && round >= 0

          # This endpoint can take a while, so we use a longer timeout
          get("status/wait-for-block-after/#{round}", timeout: 60)
        end

        private

        # Build the base URL for API endpoints
        def base_url
          "#{@server}/#{API_VERSION}"
        end

        # Create and configure Faraday connection
        def connection
          @connection ||= Faraday.new(url: base_url) do |faraday|
            faraday.request :retry, {
              max: 3,
              interval: 0.5,
              interval_randomness: 0.5,
              backoff_factor: 2,
              exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
            }
            faraday.adapter Faraday.default_adapter
            faraday.options.timeout = @timeout
            faraday.options.open_timeout = 10
          end
        end

        # Perform a GET request
        def get(path, timeout: nil)
          response = connection.get(path) do |req|
            req.headers["X-Algo-API-Token"] = @token if @token
            req.headers["Content-Type"] = "application/json"
            @headers.each { |key, value| req.headers[key] = value }
            req.options.timeout = timeout if timeout
          end

          handle_response(response)
        rescue Faraday::TimeoutError => e
          raise NetworkError, "Request timeout: #{e.message}"
        rescue Faraday::ConnectionFailed => e
          raise NetworkError, "Connection failed: #{e.message}"
        rescue Faraday::Error => e
          raise NetworkError, "Network error: #{e.message}"
        end

        # Handle API response
        def handle_response(response)
          case response.status
          when 200..299
            parse_json(response.body)
          when 400
            raise ApiError.new("Bad request", status: response.status, body: response.body)
          when 401
            raise ApiError.new("Unauthorized - check your API token", status: response.status, body: response.body)
          when 404
            raise ApiError.new("Not found", status: response.status, body: response.body)
          when 500..599
            raise ApiError.new("Server error", status: response.status, body: response.body)
          else
            raise ApiError.new("Unexpected status: #{response.status}", status: response.status, body: response.body)
          end
        end

        # Parse JSON response
        def parse_json(body)
          JSON.parse(body)
        rescue JSON::ParserError => e
          raise ApiError, "Invalid JSON response: #{e.message}"
        end
      end
    end
  end
end
