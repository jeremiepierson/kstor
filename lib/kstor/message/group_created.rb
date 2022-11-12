# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for group created.
    class GroupCreated < Base
      message_type :group_created, response: true

      arg :group_id
      arg :group_name
      arg :group_pubk
    end
  end
end
