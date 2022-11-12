# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for group_get.
    class GroupInfo < Base
      message_type :group_info, response: true

      arg :id
      arg :name
      arg :members
    end
  end
end
