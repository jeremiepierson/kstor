# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to rename a group.
    class GroupRename < Base
      message_type :group_rename, request: true

      arg :name
      arg :group_id
    end
  end
end
