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
  #
  # FIXME: create one subclass for each request and response types.
  class Message
    attr_reader :type
    attr_reader :args

    # Create new message.
    #
    # @param type [String] message type
    # @param args [Hash] message arguments
    # @return [KStor::Message] new message
    def initialize(type, args)
      @type = type
      @args = args
    end

    # Convert this message to a Hash
    #
    # @return [Hash] this message as a Hash.
    def to_h
      { 'type' => @type, 'args' => @args }
    end

    # Serialize this message to JSON.
    #
    # @return [String] JSON data.
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
  #
  # Can be of any type.
  class LoginRequest < Message
    attr_reader :login
    attr_reader :password

    # Create an authenticated request.
    #
    # @param login [String] login of user
    # @param password [String] password of user
    # @param type [String] type of request
    # @param args [Hash] arguments of request
    # @return [KStor::LoginRequest] new request
    def initialize(login, password, type, args)
      @login = login
      @password = password
      super(type, args)
    end

    # Hide sensitive information when debugging.
    def inspect
      fmt = [
        '#<KStor::LoginRequest:%<id>x',
        '@login=%<login>s',
        '@password="******"',
        '@args=%<args>s>'
      ].join(' ')
      format(fmt, id: object_id, login: @login.inspect, args: @args.inspect)
    end

    # Convert request to Hash.
    #
    # Used for JSON serialization.
    #
    # @return [Hash] this request as a Hash.
    def to_h
      super.merge('login' => @login, 'password' => @password)
    end
  end

  # A user request with a session ID.
  #
  # Can be of any type.
  class SessionRequest < Message
    attr_reader :session_id

    # Create a new request.
    #
    # @param session_id [String] session ID
    # @param type [String] type of request
    # @param args [Hash] arguments of request
    # @return [KStor::SessionRequest] new request
    def initialize(session_id, type, args)
      @session_id = session_id
      super(type, args)
    end

    # Hide sensitive information when debugging.
    def inspect
      fmt = [
        '#<KStor::SessionRequest:%<id>x',
        '@session_id=******',
        '@args=%<args>s>'
      ].join(' ')
      format(fmt, id: object_id, args: @args.inspect)
    end

    # Convert request to Hash.
    #
    # Used for JSON serialization.
    #
    # @return [Hash] this request as a Hash.
    def to_h
      super.merge('session_id' => @session_id)
    end
  end

  # Response to a user request.
  class Response < Message
    # Session ID of authenticated user.
    attr_accessor :session_id

    # Create a new response.
    #
    # @param type [String] message type
    # @param args [Hash] message arguments
    # @return [KStor::Message] new response
    def initialize(type, args)
      @session_id = nil
      super
    end

    # Parse request from JSON data.
    #
    # @param str [String] JSON data
    # @return [KStor::Response] new response
    # @raise [JSON::ParserError] on invalid JSON data
    def self.parse(str)
      data = JSON.parse(str)
      resp = new(data['type'], data['args'])
      resp.session_id = data['session_id']
      resp
    rescue JSON::ParserError => e
      raise UnparsableResponse, e.message
    end

    # True if response type is an error.
    #
    # @return [Boolean] true if error
    def error?
      @type == 'error'
    end

    # Convert response to Hash.
    #
    # Used for JSON serialization.
    #
    # @return [Hash] this response as a Hash.
    def to_h
      super.merge('session_id' => @session_id)
    end
  end
end
