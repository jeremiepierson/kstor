# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to delete a group.
    class GroupDelete < Base
      message_type :group_delete, request: true

      arg :group_id
    end
  end
end
