# frozen_string_literal: true

require 'kstor/message/request'

module KStor
  module Message
    # Request to search secrets.
    class SecretSearch < Request
      message_type :secret_search

      # Create a new secret-search request.
      #
      # @param meta [Hash] Secret metadata wildcards
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(meta:, **opts)
        super({ 'meta' => meta }, **opts)
      end

      # Secret metadata wildcards.
      def meta
        @args['meta']
      end
    end
  end
end
