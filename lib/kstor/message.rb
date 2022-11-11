# frozen_string_literal: true

require 'json'

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

    # A user request or response.
    #
    # FIXME: create one subclass for each request and response types.
    class Base
      attr_reader :type
      attr_reader :args

      # Create new message.
      #
      # @param type [String] message type
      # @param args [Hash] message arguments
      # @return [KStor::Message::Base] new message
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
    end

    # A client request.
    class Request < Base
      attr_reader :login
      attr_reader :password
      attr_reader :session_id

      # Create a new request.
      def initialize(type, args, **opts)
        super(type, args)
        if opts.key?(:login) && opts.key?(:password)
          @login = opts[:login]
          @password = opts[:password]
        elsif opts.key?(:session_id)
          @session_id = opts[:session_id]
        else
          raise RequestMissesAuthData
        end
      end

      # True if it's a login/password request.
      def login?
        !(@login.nil? || @password.nil?)
      end

      # True if it's a session request
      def session?
        !@session_id.nil?
      end

      # Convert request to Hash.
      #
      # Used for JSON serialization.
      #
      # @return [Hash] this request as a Hash.
      def to_h
        if login?
          super.merge('login' => @login, 'password' => @password)
        elsif session?
          super.merge('session_id' => @session_id)
        else
          raise RequestMissesAuthData
        end
      end

      # Hide sensitive information when debugging.
      def inspect
        if login?
          inspect_login_request
        elsif session?
          inspect_session_request
        else
          raise RequestMissesAuthData
        end
      end

      # Parse a user request, freshly arrived from the network.
      #
      # @param str [String] serialized request
      # @return [KStor::Message::Request] a request
      # @raise [KStor::RequestMissesAuthData]
      def self.parse(str)
        data = JSON.parse(str)
        if data.key?('login') && data.key?('password')
          new(
            data['type'], data['args'],
            login: data['login'], password: data['password']
          )
        elsif data.key?('session_id')
          new(
            data['type'], data['args'], session_id: data['session_id']
          )
        else
          raise RequestMissesAuthData
        end
      end

      private

      def inspect_login_request
        fmt = [
          '#<KStor::Message::Request:%<id>x',
          '@type=%<type>s',
          '@login=%<login>s',
          '@password="******"',
          '@args=%<args>s>'
        ].join(' ')
        format(
          fmt,
          id: object_id, type: @type.inspect, login: @login.inspect,
          args: @args.inspect
        )
      end

      def inspect_session_request
        fmt = [
          '#<KStor::Message::Request:%<id>x',
          '@type=%<type>s',
          '@session_id=******',
          '@args=%<args>s>'
        ].join(' ')
        format(fmt, id: object_id, type: @type, args: @args.inspect)
      end
    end

    # Response to a user request.
    class Response < Base
      # Session ID of authenticated user.
      attr_accessor :session_id

      # Create a new response.
      #
      # @param type [String] message type
      # @param args [Hash] message arguments
      # @return [KStor::Message::Base] new response
      def initialize(type, args)
        @session_id = nil
        super
      end

      # Parse request from JSON data.
      #
      # @param str [String] JSON data
      # @return [KStor::Message::Response] new response
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
end
