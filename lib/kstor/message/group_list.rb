# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for group search.
    class GroupList < Base
      message_type :group_list, response: true

      arg :groups
    end
  end
end
