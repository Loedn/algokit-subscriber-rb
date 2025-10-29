# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Algokit
  module Subscriber
    module Client
      # HTTP client for Algorand indexer API
      #
      # Provides methods to search and retrieve historical transaction data from
      # the Algorand indexer for fast catchup and historical analysis.
      #
      # @example
      #   indexer = IndexerClient.new('https://testnet-idx.algonode.cloud')
      #   transactions = indexer.search_transactions(
      #     min_round: 1000,
      #     max_round: 2000,
      #     address: 'ABC123...'
      #   )
      class IndexerClient
        API_VERSION = "v2"
        DEFAULT_TIMEOUT = 30
        DEFAULT_LIMIT = 1000

        # @param server [String] The indexer server URL
        # @param token [String, nil] Optional API token for authentication
        # @param headers [Hash] Optional additional headers
        # @param timeout [Integer] Request timeout in seconds (default: 30)
        def initialize(server, token: nil, headers: {}, timeout: DEFAULT_TIMEOUT)
          @server = server.sub(%r{/+$}, "") # Remove trailing slashes
          @token = token
          @headers = headers
          @timeout = timeout
        end

        # Search for transactions with optional filters
        #
        # This method supports pagination via the `next` parameter. When results
        # span multiple pages, the response will include a 'next-token' field.
        #
        # @param params [Hash] Search parameters
        # @option params [Integer] :min_round Minimum round (inclusive)
        # @option params [Integer] :max_round Maximum round (inclusive)
        # @option params [String] :address Filter by account address
        # @option params [String] :address_role Role of address (sender|receiver|freeze-target)
        # @option params [String] :tx_type Transaction type (pay|keyreg|acfg|axfer|afrz|appl|stpf)
        # @option params [Integer] :asset_id Filter by asset ID
        # @option params [Integer] :application_id Filter by application ID
        # @option params [String] :note_prefix Filter by note prefix (base64)
        # @option params [Integer] :currency_greater_than Min amount transferred
        # @option params [Integer] :currency_less_than Max amount transferred
        # @option params [Integer] :limit Results per page (default: 1000, max: 1000)
        # @option params [String] :next Pagination token for next page
        #
        # @return [Hash] Search results with transactions array and optional next-token
        # @raise [ApiError] if the API returns an error
        # @raise [NetworkError] if a network error occurs
        #
        # @example Basic search
        #   results = indexer.search_transactions(
        #     min_round: 1000,
        #     max_round: 2000
        #   )
        #
        # @example With pagination
        #   results = indexer.search_transactions(min_round: 1000, max_round: 2000)
        #   all_txns = results['transactions']
        #
        #   while results['next-token']
        #     results = indexer.search_transactions(
        #       min_round: 1000,
        #       max_round: 2000,
        #       next: results['next-token']
        #     )
        #     all_txns.concat(results['transactions'])
        #   end
        def search_transactions(params = {})
          query_params = build_query_params(params)
          get("transactions", query_params)
        end

        # Check indexer health
        #
        # @return [Hash] Health status
        # @raise [ApiError] if the indexer is unhealthy
        def health
          get("health")
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
        def get(path, params = {})
          response = connection.get(path) do |req|
            req.headers["X-Indexer-API-Token"] = @token if @token
            req.headers["Content-Type"] = "application/json"
            @headers.each { |key, value| req.headers[key] = value }
            req.params = params unless params.empty?
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

        # Build query parameters for search_transactions
        def build_query_params(params)
          query = {}

          # Round filters
          query["min-round"] = params[:min_round] if params[:min_round]
          query["max-round"] = params[:max_round] if params[:max_round]

          # Address filters
          query["address"] = params[:address] if params[:address]
          query["address-role"] = params[:address_role] if params[:address_role]

          # Transaction type
          query["tx-type"] = params[:tx_type] if params[:tx_type]

          # Asset and application filters
          query["asset-id"] = params[:asset_id] if params[:asset_id]
          query["application-id"] = params[:application_id] if params[:application_id]

          # Note prefix (should be base64 encoded)
          query["note-prefix"] = params[:note_prefix] if params[:note_prefix]

          # Currency filters
          query["currency-greater-than"] = params[:currency_greater_than] if params[:currency_greater_than]
          query["currency-less-than"] = params[:currency_less_than] if params[:currency_less_than]

          # Pagination
          query["limit"] = params[:limit] || DEFAULT_LIMIT
          query["next"] = params[:next] if params[:next]

          query
        end
      end
    end
  end
end
