# frozen_string_literal: true

require 'kstor/message/response'

module KStor
  module Message
    # Error response.
    class Error < Response
      message_type :error

      # Create a new error response.
      #
      # @param code [String] error code
      # @param message [String] error message
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(code:, message:, **opts)
        super({ 'code' => code, 'message' => message }, **opts)
      end

      # Error code.
      def code
        @args['code']
      end

      # Error message
      def message
        @args['message']
      end
    end
  end
end
