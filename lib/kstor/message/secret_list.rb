# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response for secret search.
    class SecretList < Base
      message_type :secret_list, response: true

      arg :secrets
    end
  end
end
