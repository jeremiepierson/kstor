# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to create a secret.
    class SecretCreate < Base
      message_type :secret_create, request: true

      arg :meta
      arg :group_ids
      arg :plaintext
    end
  end
end
