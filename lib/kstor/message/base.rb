# frozen_string_literal: true

module KStor
  module Message
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
  end
end
