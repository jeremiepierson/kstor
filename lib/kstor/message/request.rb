# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
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
  end
end
