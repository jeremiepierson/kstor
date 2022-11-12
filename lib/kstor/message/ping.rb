# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Ping server.
    class Ping < Base
      message_type :ping, request: true

      arg :payload
    end
  end
end
