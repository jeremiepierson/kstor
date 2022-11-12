# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to get info on a group.
    class GroupGet < Base
      message_type :group_get, request: true

      arg :group_id
    end
  end
end
