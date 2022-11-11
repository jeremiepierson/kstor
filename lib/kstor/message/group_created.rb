# frozen_string_literal: true

require 'kstor/message/response'

module KStor
  module Message
    # Response for group created.
    class GroupCreated < Response
      message_type :group_created

      # Create a new group-created response.
      #
      # @param group_id [Integer] ID of new group
      # @param group_name [String] name of new group
      # @param group_pubk [KStor::Crypto::PublicKey] public key of new group
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(group_id:, group_name:, group_pubk:, **opts)
        args = {
          'group_id' => group_id,
          'group_name' => group_name,
          'group_pubk' => group_pubk
        }
        super(args, **opts)
      end

      # New group ID.
      def group_id
        @args['group_id']
      end

      # New group name
      def group_name
        @args['group_name']
      end

      # New group public key
      def group_pubk
        @args['group_pubk']
      end
    end
  end
end
