# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to delete a secret.
    class SecretDelete < Base
      message_type :secret_delete, request: true

      arg :secret_id
    end
  end
end
