# frozen_string_literal: true

require 'kstor/message/request'

module KStor
  module Message
    # Request to decrypt a secret.
    class SecretUnlock < Request
      message_type :secret_unlock

      # Create a new secret-unlock request.
      #
      # @param secret_id [Integer] ID of secret to decrypt.
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(secret_id:, **opts)
        super({ 'secret_id' => secret_id }, **opts)
      end

      # ID of secret to decrypt.
      def secret_id
        @args['secret_id']
      end
    end
  end
end
