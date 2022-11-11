# frozen_string_literal: true

require 'kstor/message/response'

module KStor
  module Message
    # Response for secret search.
    class SecretList < Response
      message_type :secret_list

      # Create a new secret-list response.
      #
      # @param secrets [Array[Hash]] List of secrets
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(secrets:, **opts)
        super({ 'secrets' => secrets }, **opts)
      end

      # List of secrets.
      def secrets
        @args['secrets']
      end
    end
  end
end
