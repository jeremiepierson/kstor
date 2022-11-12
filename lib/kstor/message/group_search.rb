# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to search groups.
    class GroupSearch < Base
      message_type :group_search, request: true

      arg :name
    end
  end
end
