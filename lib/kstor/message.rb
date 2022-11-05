# frozen_string_literal: true

require 'json'

module KStor
  # Internal exception when a request is received with neither a session ID nor
  # a login/password pair.
  #
  # We can't use a KStor::Error here because kstor/error.rb require()s
  # kstor/message.rb .
  class RequestMissesAuthData < RuntimeError
  end

  class UnparsableResponse < RuntimeError
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

    # Parse a user request, freshly arrived from the network.
    #
    # @param str [String] serialized request
    # @return [LoginRequest,SessionRequest] a request
    # @raise [KStor::RequestMissesAuthData]
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

    def initialize(login, password, type, args)
      @login = login
      @password = password
      super(type, args)
    end

    def inspect
      fmt = [
        '#<KStor::LoginRequest:%<id>x',
        '@login=%<login>s',
        '@password="******"',
        '@args=%<args>s>'
      ].join(' ')
      format(fmt, id: object_id, login: @login.inspect, args: @args.inspect)
    end

    def to_h
      super.merge('login' => @login, 'password' => @password)
    end
  end

  # A user request with a session ID.
  class SessionRequest < Message
    attr_reader :session_id

    def initialize(session_id, type, args)
      @session_id = session_id
      super(type, args)
    end

    def inspect
      fmt = [
        '#<KStor::SessionRequest:%<id>x',
        '@session_id=******',
        '@args=%<args>s>'
      ].join(' ')
      format(fmt, id: object_id, args: @args.inspect)
    end

    def to_h
      super.merge('session_id' => @session_id)
    end
  end

  # Response to a user request.
  class Response < Message
    attr_accessor :session_id

    def initialize(type, args)
      @session_id = nil
      super
    end

    def self.parse(str)
      data = JSON.parse(str)
      resp = new(data['type'], data['args'])
      resp.session_id = data['session_id']
      resp
    rescue JSON::ParserError => e
      raise UnparsableResponse, e.message
    end

    def error?
      @type == 'error'
    end

    def to_h
      super.merge('session_id' => @session_id)
    end
  end
end
