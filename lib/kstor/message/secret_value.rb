# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for secret unlock.
    class SecretValue < Base
      message_type :secret_value, response: true

      arg :id
      arg :value_author
      arg :metadata_author
      arg :metadata
      arg :plaintext
      arg :groups

      # Create a new secret-value response.
      #
      # @option opts [Integer] :id ID of secret
      # @option opts [Hash] :value_author info on user that created secret value
      # @option opts [Hash] :metadata_author info on user that created secret
      #   metadata
      # @option opts [Hash] :metadata metadata of this secret
      # @option opts [String] :plaintext decrypted value of secret
      # @option opts [Array[Hash]] :groups list of groups that can decrypt this
      #   secret
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(**opts)
        super(**opts)
        opts.delete(:group_id)
      end
    end
  end
end
