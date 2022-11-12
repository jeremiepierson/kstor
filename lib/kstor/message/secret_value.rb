# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for secret unlock.
    class SecretValue < Base
      message_type :secret_value, response: true

      arg :id
      arg :value_author
      arg :metadata_author
      arg :metadata
      arg :plaintext
      arg :groups
    end
  end
end
