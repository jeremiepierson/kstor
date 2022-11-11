# frozen_string_literal: true

require 'kstor/message/request'

module KStor
  module Message
    # Request to update secret value.
    class SecretUpdateValue < Request
      message_type :secret_update_value

      # Create a new secret-update-value request.
      #
      # @param plaintext [String] New value
      # @param secret_id [Integer] ID of secret to update
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(plaintext:, secret_id:, **opts)
        super({ 'plaintext' => plaintext, 'secret_id' => secret_id }, **opts)
      end

      # New secret value.
      def plaintext
        @args['plaintext']
      end

      # ID of secret to update
      def secret_id
        @args['secret_id']
      end
    end
  end
end
