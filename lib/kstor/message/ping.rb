# frozen_string_literal: true

require 'kstor/message/request'

module KStor
  module Message
    # Ping server.
    class Ping < Request
      message_type :ping

      # Create a new ping request.
      #
      # @param payload [String] arbitrary string
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(payload:, **opts)
        super({ 'payload' => payload }, **opts)
      end

      # Content of ping request.
      def payload
        @args['payload']
      end
    end
  end
end
