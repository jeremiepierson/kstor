# frozen_string_literal: true

require 'kstor/message/base'

module KStor
  module Message
    # Response to a user request.
    class Response < Base
      # Session ID of authenticated user.
      attr_accessor :session_id

      # Create a new response.
      #
      # @param type [String] message type
      # @param args [Hash] message arguments
      # @return [KStor::Message::Base] new response
      def initialize(type, args, session_id: nil)
        super(type, args)
        @session_id = session_id
      end

      # Parse request from JSON data.
      #
      # @param str [String] JSON data
      # @return [KStor::Message::Response] new response
      # @raise [JSON::ParserError] on invalid JSON data
      def self.parse(str)
        data = JSON.parse(str)
        new(data['type'], data['args'], session_id: data['session_id'])
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
