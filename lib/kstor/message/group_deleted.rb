# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for group deleted.
    class GroupDeleted < Base
      message_type :group_deleted, response: true

      arg :group_id
    end
  end
end
