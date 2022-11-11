# frozen_string_literal: true

require 'kstor/message/response'

module KStor
  module Message
    # Response for secret deleted.
    class SecretDeleted < Response
      message_type :secret_deleted

      # Create a new secret-deleted response.
      #
      # @param secret_id [Integer] ID of deleted secret
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(secret_id:, **opts)
        super({ 'secret_id' => secret_id }, **opts)
      end

      # ID of deleted secret.
      def secret_id
        @args['secret_id']
      end
    end
  end
end
