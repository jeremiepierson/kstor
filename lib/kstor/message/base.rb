# frozen_string_literal: true

module KStor
  module Message
    # Basically an Array of message subclasses, with an index on message type.
    #
    # @api private
    class Registry
      # Create new registry.
      def initialize
        @message_classes = []
        @index = nil
      end

      # List of subclasses.
      def classes
        @message_classes.values
      end

      # Append a message class.
      def <<(klass)
        @message_classes << klass
        @index = nil
      end

      # True if registry knows a subclass with this message type.
      def key?(type)
        index.key?(type)
      end

      # Return subclass for this message type.
      def [](type)
        index[type]
      end

      # List of known message types.
      def types
        index.keys
      end

      private

      def index
        @message_classes.delete_if { |c| c.type.nil? }
        @index ||= @message_classes.to_h { |c| [c.type, c] }
      end
    end

    # A user request or response.
    class Base
      attr_reader :type
      attr_reader :args

      # Create new message.
      #
      # @param type [String] message type
      # @param args [Hash] message arguments
      # @return [KStor::Message::Base] new message
      def initialize(type, args)
        @type = type.to_s
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

      class << self
        attr_reader :type

        # rubocop:disable Style/ClassVars
        @@registry = Registry.new
        # rubocop:enable Style/ClassVars

        # Declare message type
        def message_type(name)
          @type = name
        end

        # Create a new message of the given type
        def for_type(name, args, **opts)
          klass = @@registry[name.to_sym]
          raise "unknown message type #{name.inspect}" unless klass

          klass.new(**args, **opts)
        end

        # True if message type "name" is known.
        def type?(name)
          @@registry.key?(name)
        end

        # List of known types.
        def types
          @@registry.types
        end

        # Parse message.
        def parse(str)
          data = JSON.parse(str)
          type = data.delete('type').to_sym
          args = data.delete('args').transform_keys(&:to_sym)
          opts = data.transform_keys(&:to_sym)
          for_type(type, args, **opts)
        rescue JSON::ParserError
          raise UnparsableResponse
        end

        # When subclassed, add child to registry.
        def inherited(subclass)
          super
          if @@registry.key?(subclass.type)
            message_type = subclass.type
            klass = @@registry[message_type]
            raise "duplicate message type #{message_type} in #{subclass}, " \
                  "already defined in #{klass}"
          end
          @@registry << subclass
        end
      end
    end
  end
end
