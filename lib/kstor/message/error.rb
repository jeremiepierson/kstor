# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Error response.
    class Error < Base
      message_type :error, response: true

      arg :code
      arg :message
    end
  end
end
