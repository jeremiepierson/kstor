# frozen_string_literal: true

module KStor
  # Units of communication between server and clients.
  module Message
    # A user request or response.
    class Base
      attr_reader :args

      # Create new message.
      #
      # @param args [Hash] message arguments
      # @param auth [Hash] authentication data
      # @return [KStor::Message::Base] new message
      def initialize(args, auth = {})
        @args = check_args!(args)
        @auth = check_auth!(auth.compact)
      end

      # Message type.
      def type
        self.class.type
      end

      # User login
      def login
        @auth[:login]
      end

      # User password
      def password
        @auth[:password]
      end

      # User session ID
      def session_id
        @auth[:session_id]
      end

      # Change user session ID.
      #
      # Should only be used when password was just changed.
      def session_id=(sid)
        @auth[:session_id] = sid
      end

      # True if this message is a request.
      def request?
        self.class.request
      end

      # True if this message is a response.
      def response?
        !request?
      end

      # True if this message is an error response.
      def error?
        response? && type == :error
      end

      # True if this message is a request and has login and password arguments.
      def login_request?
        request? && @auth.key?(:login) && @auth.key?(:password)
      end

      # True if this message is a request and has a session ID.
      def session_request?
        request? && @auth.key?(:session_id)
      end

      # Convert this message to a Hash
      #
      # @return [Hash] this message as a Hash.
      def to_h
        h = { 'type' => type.to_s, 'args' => @args }
        if login_request?
          h['login'] = @auth[:login]
          h['password'] = @auth[:password]
        elsif session_request? || response?
          h['session_id'] = @auth[:session_id]
        end

        h
      end

      # Hide sensitive information when debugging
      def inspect
        if login_request?
          inspect_login_request
        elsif session_request? || response?
          inspect_session_request_or_response
        else
          raise 'WTFBBQ?!???1!11!'
        end
      end

      # Serialize this message to JSON.
      #
      # @return [String] JSON data.
      def serialize
        to_h.to_json
      end

      class << self
        attr_reader :type
        attr_reader :request
        attr_reader :registry
        attr_reader :arg_names

        # Declare message type and direction (request or response).
        def message_type(name, request: nil, response: nil)
          @type = name
          if (request && response) || (!request && !response)
            raise 'Is it a request or a response type?!?'
          end

          @request = !!request
        end

        # Declare an argument to this message type.
        def arg(name)
          @arg_names ||= []
          @arg_names << name.to_s
          define_method(name) do
            @args[name.to_s]
          end
        end

        # Create a new message of the given type
        def for_type(name, args, auth)
          klass = @registry[name.to_sym]
          raise "unknown message type #{name.inspect}" unless klass

          klass.new(args, auth)
        end

        # True if message type "name" is known.
        def type?(name)
          @registry.key?(name.to_sym)
        end

        # List of known types.
        def types
          @registry.values
        end

        # Parse message.
        def parse(str)
          data = JSON.parse(str)
          type = data.delete('type').to_sym
          args = data.delete('args').transform_keys(&:to_s)
          auth = data.transform_keys(&:to_sym)
          for_type(type, args, auth)
        rescue JSON::ParserError
          raise UnparsableResponse
        end

        # Register new message type.
        def register(klass)
          @registry ||= {}
          unless klass.respond_to?(:type) && klass.respond_to?(:request)
            raise "#{klass} is not a subclass of #{self}"
          end

          if @registry.key?(klass.type)
            message_type = subclass.type
            old_klass = @registry[message_type]
            raise "duplicate message type #{message_type} in #{klass}, " \
                  "already defined in #{old_klass}"
          end
          @registry[klass.type] = klass
        end
      end

      private

      def check_auth!(opts)
        return opts if response?
        return opts if opts.key?(:login) && opts.key?(:password)
        return opts if opts.key?(:session_id)

        raise RequestMissesAuthData
      end

      def check_args!(raw_args)
        args = self.class.arg_names.to_h { |name| [name, raw_args[name]] }
        missing = args.select { |_, v| v.nil? }.keys
        unless missing.empty?
          raise MissingMessageArgument.new(missing.inspect, type)
        end

        args
      end

      def inspect_login_request
        base_inspect(
          ['@login=%<login>s', '@password="******"'],
          login: @auth[:login].inspect
        )
      end

      def inspect_session_request_or_response
        base_inspect(['@session_id=******'])
      end

      def base_inspect(fmt_parts, **fmt_args)
        begin_fmt = ["#<#{self.class}:%<id>x", '@type=%<type>s']
        end_fmt = ['@args=%<args>s>']
        fmt = (begin_fmt + fmt_parts + end_fmt).join(' ')
        args = fmt_args.merge(
          id: object_id, type: type.inspect, args: @args.inspect
        )
        format(fmt, **args)
      end
    end

    class << self
      # Register new message type.
      def register_all_message_types
        constants(false).each do |const|
          klass = const_get(const)
          next unless klass.respond_to?(:superclass) && klass.superclass == Base

          Base.register(klass)
        end
      end
    end
  end
end
