# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response telling that group update was successful.
    class GroupUpdated < Base
      message_type :group_updated, response: true

      arg :group_id
    end
  end
end
