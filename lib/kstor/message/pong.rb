# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Ping response.
    class Pong < Base
      message_type :pong, response: true

      arg :payload
    end
  end
end
