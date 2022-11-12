# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Request to search secrets.
    class SecretSearch < Base
      message_type :secret_search, request: true

      arg :meta
    end
  end
end
