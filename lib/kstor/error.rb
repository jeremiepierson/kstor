# frozen_string_literal: true

require 'kstor/message'

module KStor
  # Base class of KStor errors.
  #
  # Each subclass declares a code and is stored in a global registry.
  class Error < StandardError
    class << self
      attr_reader :code
      attr_reader :message
      attr_reader :registry

      # Declare error code for a subclass.
      #
      # @param str [String] unique error code.
      def error_code(str)
        @code = str
      end

      # Declare error message for a subclass.
      #
      # This will be passed to String#format as a format string.
      #
      # @param str [String] error message or format.
      def error_message(str)
        @message = str
      end

      # Create a new error for this code.
      #
      # @param code [String] error code
      # @param args [Array] arguments to subclass initialize method.
      def for_code(code, *args)
        @registry[code].new(*args)
      end

      # List of all subclasses.
      def list
        @registry.classes
      end
    end

    # When subclassed, add child to registry.
    #
    # @param subclass [Class] subclass to add to error registry.
    def self.inherited(subclass)
      super
      @registry ||= ErrorRegistry.new
      if @registry.key?(subclass.code)
        code = subclass.code
        klass = @registry[code]
        raise "duplicate error code #{code} in #{subclass}, " \
              "already defined in #{klass}"
      end

      @registry << subclass
    end

    # Create new error.
    #
    # @param args [Array] arguments to String#format with the message as a
    #   format string.
    # @return [KStor::Error] instance of subclass of Error.
    def initialize(*args)
      super(format("ERR/%s #{self.class.message}", self.class.code, *args))
    end

    # Create a new server response from an error.
    #
    # @return [KStor::Message::Error] error response
    def response(sid)
      Message::Error.new(
        { 'code' => self.class.code, 'message' => message },
        { session_id: sid }
      )
    end
  end

  # Basically an Array of error subclasses, with an index on error codes.
  #
  # @api private
  class ErrorRegistry
    # Create new registry.
    def initialize
      @error_classes = []
      @index = nil
    end

    # List of subclasses.
    def classes
      @error_classes
    end

    # Append an error class.
    def <<(klass)
      @error_classes << klass
      @index = nil
    end

    # True if registry knows a subclass with this error code.
    def key?(code)
      index.key?(code)
    end

    # Return subclass for this error code.
    def [](code)
      index[code]
    end

    private

    def index
      @index ||= @error_classes.to_h { |c| [c.code, c] }
    end
  end
end
