# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for secret created.
    class SecretCreated < Base
      message_type :secret_created, response: true

      arg :secret_id
    end
  end
end
