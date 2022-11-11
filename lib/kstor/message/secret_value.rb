# frozen_string_literal: true

require 'kstor/message/response'

module KStor
  module Message
    # Response for secret unlock.
    class SecretValue < Response
      message_type :secret_value

      # Create a new secret-value response.
      #
      # @option opts [Integer] :id ID of secret
      # @option opts [Hash] :value_author info on user that created secret value
      # @option opts [Hash] :meta_author info on user that created secret
      #   metadata
      # @option opts [String] :plaintext decrypted value of secret
      # @option opts [Array[Hash]] :groups list of groups that can decrypt this
      #   secret
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(**opts)
        p opts.keys
        args = {}
        args['id'] = opts.delete(:id)
        args['value_author'] = opts.delete(:value_author)
        args['metadata_author'] = opts.delete(:metadata_author)
        args['plaintext'] = opts.delete(:plaintext)
        args['metadata'] = opts.delete(:metadata)
        args['groups'] = opts.delete(:groups)
        opts.delete(:group_id)
        super(args, **opts)
      end

      # Secret ID.
      def id
        @args['id']
      end

      # Creator of secret metadata.
      def meta_author
        @args['meta_author']
      end

      # Creator of secret value
      def value_author
        @args['value_author']
      end

      # Decrypted secret value
      def plaintext
        @args['plaintext']
      end

      # Groups that can read this secret
      def groups
        @args['groups']
      end
    end
  end
end
