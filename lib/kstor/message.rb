# frozen_string_literal: true

require 'json'

module KStor
  class RequestMissesAuthData < RuntimeError
  end

  # A user request or response.
  class Message
    attr_reader :type
    attr_reader :args

    def initialize(type, args)
      @type = type
      @args = args
    end

    def to_h
      { 'type' => @type, 'args' => @args }
    end

    def serialize
      to_h.to_json
    end

    def self.parse_request(str)
      data = JSON.parse(str)
      if data.key?('login') && data.key?('password')
        LoginRequest.new(
          data['login'], data['password'],
          data['type'], data['args']
        )
      elsif data.key?('session_id')
        SessionRequest.new(
          data['session_id'], data['type'], data['args']
        )
      else
        raise RequestMissesAuthData
      end
    end
  end

  # A user authentication request.
  class LoginRequest < Message
    attr_reader :login
    attr_reader :password

    def initialize(login, password, *args)
      @login = login
      @password = password
      super(*args)
    end

    def inspect
      format(
        '#<Request:%<id>x @login=%<login>s @password="******" @args=%<args>s',
        id: __id__,
        login: @login.inspect,
        args: @args.inspect
      )
    end

    def to_h
      super.merge('login' => @login, 'password' => @password)
    end
  end

  # A user request with a session ID.
  class SessionRequest < Message
    attr_reader :session_id

    def initialize(session_id, *args)
      @session_id = session_id
      super(*args)
    end

    def to_h
      super.merge('session_id' => @session_id)
    end
  end

  # Response to a user request.
  class Response < Message
    def session_id=(sid)
      @args['session_id'] = sid
    end

    def self.parse(str)
      data = JSON.parse(str)
      new(data['type'], data['args'])
    end

    def error?
      @type == 'error'
    end
  end
end
