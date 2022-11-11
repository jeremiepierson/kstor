# frozen_string_literal: true

require 'kstor/message/response'

module KStor
  module Message
    # Response for secret updated.
    class SecretUpdated < Response
      message_type :secret_updated

      # Create a new secret-updated response.
      #
      # @param secret_id [Integer] ID of updated secret
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(secret_id:, **opts)
        super({ 'secret_id' => secret_id }, **opts)
      end

      # ID of updated secret.
      def secret_id
        @args['secret_id']
      end
    end
  end
end
