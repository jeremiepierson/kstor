# frozen_string_literal: true

require 'kstor/message/request'

module KStor
  module Message
    # Request to create a group of users.
    class GroupCreate < Request
      message_type :group_create

      # Create a new group-create request.
      #
      # @param name [String] new group name (must be unique)
      # @param opts [Hash[Symbol, String]] common request options
      def initialize(name:, **opts)
        super({ 'name' => name }, **opts)
      end

      # Name of group to create.
      def name
        @args['name']
      end
    end
  end
end
