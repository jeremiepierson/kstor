# frozen_string_literal: true

require 'kstor/message/request'

module KStor
  module Message
    # Request to delete a secret.
    class SecretDelete < Request
      message_type :secret_delete

      # Create a new secret-delete request.
      #
      # @param secret_id [Integer] ID of secret to delete
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(secret_id:, **opts)
        super({ 'secret_id' => secret_id }, **opts)
      end

      # ID of secret to delete
      def secret_id
        @args['secret_id']
      end
    end
  end
end
