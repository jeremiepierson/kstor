# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to create a user account.
    class UserCreate < Base
      message_type :user_create, request: true

      arg :user_login
      arg :user_name
      arg :token_lifespan
    end
  end
end
