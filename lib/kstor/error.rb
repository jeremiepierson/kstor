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

      def error_code(str)
        @code = str
      end

      def error_message(str)
        @message = str
      end

      def for_code(code, *args)
        @registry[code].new(*args)
      end

      def list
        @registry.classes
      end
    end

    def self.inherited(subclass)
      super
      Log.debug("#{subclass} inherits from Error")
      @registry ||= ErrorRegistry.new
      if @registry.key?(subclass.code)
        code = subclass.code
        klass = @registry[code]
        raise "duplicate error code #{code} in #{subclass}, " \
              "already defined in #{klass}"
      end

      @registry << subclass
    end

    def initialize(*args)
      super(format("ERR/%s #{self.class.message}", self.class.code, *args))
    end

    def response
      Response.new('error', 'code' => self.class.code, 'message' => message)
    end
  end

  # @api private
  class ErrorRegistry
    def initialize
      @error_classes = []
      @index = nil
    end

    def classes
      @error_classes.values
    end

    def <<(klass)
      @error_classes << klass
      @index = nil
    end

    def key?(code)
      index.key?(code)
    end

    def [](code)
      index[code]
    end

    private

    def index
      @index ||= @error_classes.to_h { |c| [c.code, c] }
    end
  end
end
