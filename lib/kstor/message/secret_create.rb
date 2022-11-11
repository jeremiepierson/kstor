# frozen_string_literal: true

require 'kstor/message/request'

module KStor
  module Message
    # Request to create a secret.
    class SecretCreate < Request
      message_type :secret_create

      # Create a new secret-create request.
      #
      # @param meta [Hash] metadata of new secret
      # @param group_ids [Array[Integer]] IDs of groups that will have access
      #   to this secret
      # @param plaintext [String] value of new secret
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(meta:, group_ids:, plaintext:, **opts)
        args = {
          'meta' => meta,
          'group_ids' => group_ids,
          'plaintext' => plaintext
        }
        super(args, **opts)
      end

      # Secret metadata.
      def meta
        @args['meta']
      end

      # IDs of groups that can read this secret
      def group_ids
        @args['group_ids']
      end

      # Secret value.
      def plaintext
        @args['plaintext']
      end
    end
  end
end
