# frozen_string_literal: true

require 'kstor/message/response'

module KStor
  module Message
    # Response for secret created.
    class SecretCreated < Response
      message_type :secret_created

      # Create a new secret-created response.
      #
      # @param secret_id [Integer] ID of new secret
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(secret_id:, **opts)
        super({ 'secret_id' => secret_id }, **opts)
      end

      # New secret ID.
      def secret_id
        @args['secret_id']
      end
    end
  end
end
