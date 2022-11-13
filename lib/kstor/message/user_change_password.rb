# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to change user password.
    class UserChangePassword < Base
      message_type :user_change_password, request: true

      arg :new_password
    end
  end
end
