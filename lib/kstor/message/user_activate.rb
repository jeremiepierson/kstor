# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to activate a user.
    class UserActivate < Base
      message_type :user_activate, request: true

      arg :token
    end
  end
end
