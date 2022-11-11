# frozen_string_literal: true

require 'kstor/message/response'

module KStor
  module Message
    # Ping response.
    class Pong < Response
      message_type :pong

      # Create a new ping response.
      #
      # @param payload [String] arbitrary string
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(payload:, **opts)
        super({ 'payload' => payload }, **opts)
      end

      # Content of ping response.
      def payload
        @args['payload']
      end
    end
  end
end
