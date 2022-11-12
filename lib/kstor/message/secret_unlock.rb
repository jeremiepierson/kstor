# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to decrypt a secret.
    class SecretUnlock < Base
      message_type :secret_unlock, request: true

      arg :secret_id
    end
  end
end
