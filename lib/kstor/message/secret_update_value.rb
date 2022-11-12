# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to update secret value.
    class SecretUpdateValue < Base
      message_type :secret_update_value, request: true

      arg :plaintext
      arg :secret_id
    end
  end
end
