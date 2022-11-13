# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to add a user to a group.
    class GroupAddUser < Base
      message_type :group_add_user, request: true

      arg :group_id
      arg :user_id
    end
  end
end
