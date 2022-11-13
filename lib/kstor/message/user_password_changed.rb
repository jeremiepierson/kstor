# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for changed user password.
    class UserPasswordChanged < Base
      message_type :user_password_changed, response: true

      arg :user_id
    end
  end
end
