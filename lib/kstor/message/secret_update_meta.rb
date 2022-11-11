# frozen_string_literal: true

require 'kstor/message/request'

module KStor
  module Message
    # Request to update secret metadata.
    class SecretUpdateMeta < Request
      message_type :secret_update_meta

      # Create a new secret-update-meta request.
      #
      # @param meta [Hash] New metadata
      # @param secret_id [Integer] ID of secret to update
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(meta:, secret_id:, **opts)
        super({ 'meta' => meta, 'secret_id' => secret_id }, **opts)
      end

      # New secret metadata.
      def meta
        @args['meta']
      end

      # ID of secret to update
      def secret_id
        @args['secret_id']
      end
    end
  end
end
