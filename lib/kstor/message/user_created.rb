# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for user created.
    class UserCreated < Base
      message_type :user_created, response: true

      arg :user_id
      arg :activation_token
    end
  end
end
