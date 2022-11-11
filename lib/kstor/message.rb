# frozen_string_literal: true

require 'json'

require 'kstor/message/request'
require 'kstor/message/response'

module KStor
  module Message
    # Internal exception when a request is received with neither a session ID
    # nor a login/password pair.
    #
    # We can't use a KStor::Error here because kstor/error.rb require()s
    # kstor/message.rb .
    class RequestMissesAuthData < RuntimeError
    end

    # Response data was invalid JSON.
    class UnparsableResponse < RuntimeError
    end
  end
end
