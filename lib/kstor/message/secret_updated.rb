# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for secret updated.
    class SecretUpdated < Base
      message_type :secret_updated, response: true

      arg :secret_id
    end
  end
end
