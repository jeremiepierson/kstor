# frozen_string_literal: true

module KStor
  # Units of communication between server and clients.
  module Message
    # A user request or response.
    class Base
      attr_reader :args
      attr_reader :login
      attr_reader :password
      attr_accessor :session_id

      # Create new message.
      #
      # @param args [Hash] message arguments
      # @return [KStor::Message::Base] new message
      def initialize(args, **opts)
        @args = check_args!(args)
        if request?
          if opts.key?(:login) && opts.key?(:password)
            @login = opts[:login]
            @password = opts[:password]
          elsif opts.key?(:session_id)
            @session_id = opts[:session_id]
          else
            raise RequestMissesAuthData
          end
        else
          @session_id = opts[:session_id]
        end
      end

      # Message type.
      def type
        self.class.type
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
        response? && type == 'error'
      end

      # True if this message is a request and has login and password arguments.
      def login_request?
        request? && !(@login.nil? || @password.nil?)
      end

      # True if this message is a request and has a session ID.
      def session_request?
        request? && !@session_id.nil?
      end

      # Convert this message to a Hash
      #
      # @return [Hash] this message as a Hash.
      def to_h
        h = { 'type' => type, 'args' => @args }
        if login_request?
          h['login'] = @login
          h['password'] = @password
        elsif session_request? || response?
          h['session_id'] = @session_id
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
        def for_type(name, args, **opts)
          klass = @registry[name.to_sym]
          raise "unknown message type #{name.inspect}" unless klass

          klass.new(args, **opts)
        end

        # True if message type "name" is known.
        def type?(name)
          @registry.key?(name.to_sym)
        end

        # List of known types.
        def types
          @registry.types
        end

        # Parse message.
        def parse(str)
          data = JSON.parse(str)
          type = data.delete('type').to_sym
          args = data.delete('args').transform_keys(&:to_s)
          opts = data.transform_keys(&:to_sym)
          for_type(type, args, **opts)
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
          login: @login.inspect
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
