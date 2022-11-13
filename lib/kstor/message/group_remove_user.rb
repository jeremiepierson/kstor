# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to remove a user from a group.
    class GroupRemoveUser < Base
      message_type :group_remove_user, request: true

      arg :group_id
      arg :user_id
    end
  end
end
