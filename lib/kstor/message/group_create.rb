# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to create a group of users.
    class GroupCreate < Base
      message_type :group_create, request: true

      arg :name
    end
  end
end
