# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for secret deleted.
    class SecretDeleted < Base
      message_type :secret_deleted, response: true

      arg :secret_id
    end
  end
end
