# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for updated user.
    class UserUpdated < Base
      message_type :user_updated, response: true

      arg :user_id
    end
  end
end
