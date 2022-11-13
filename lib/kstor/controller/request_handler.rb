# frozen_string_literal: true

require 'rbnacl'

require 'kstor/error'
require 'kstor/controller/authentication'
require 'kstor/controller/secret'
require 'kstor/controller/users'
require 'kstor/controller/groups'

module KStor
  module Controller
    # Undeclared response type.
    class UnknownResponseType < RuntimeError
    end

    # Top-level request handler.
    #
    # Dispatches requests to specialized sub-controller.
    class RequestHandler
      class << self
        # List of sub-controllers.
        attr_accessor :controllers

        # Request types handled by all sub-controllers.
        #
        # @return [Array[String]] list of all handled request types
        def request_types
          @controllers.map(&:request_types).inject([], &:+)
        end

        # Response types that sub-controllers can produce.
        #
        # @return [Array[String]] list of all response types that this handler
        #   can produce
        def response_types
          [Message::Error] + @controllers.map(&:response_types).inject([], &:+)
        end

        # All message types handled and produced by this controller.
        #
        # @return [Array[String]] List of all message types
        def message_types
          request_types + response_types
        end

        # True if this controller can handle this request type.
        #
        # @param type [Class] request type
        # @return [Boolean] true if handled
        def handles?(type)
          request_types.include?(type)
        end

        # True if this controller can respond to a client with this type of
        # reponse.
        #
        # @param type [String] response type
        # @return [Boolean] true if can be produced.
        def responds?(type)
          response_types.include?(type)
        end
      end

      self.controllers = [
        Controller::User, Controller::Group, Controller::Secret
      ]

      # Create new request handler controller from data store and session store.
      #
      # @param store [KStor::Store] data store
      # @param session_store [KStor::SessionStore] session store
      # @return [KStor::Controller::RequestHandler] new top-level controller.
      def initialize(store, session_store)
        @auth = Controller::Authentication.new(store, session_store)
        @store = store
        @controllers = self.class.controllers.map do |klass|
          klass.new(store)
        end
      end

      # Serve a client.
      #
      # @param req [KStor::Message::Base] client request
      # @return [KStor::Message::Base] server response
      def handle_request(req)
        user, sid = @auth.authenticate(req)
        controller = controller_from_request_type(req)
        resp = @store.transaction { controller.handle_request(user, sid, req) }
        handle_password_changed(req, resp, user)
        user.lock
        finish_response(resp)
      rescue RbNaClError => e
        Log.exception(e)
        Error.for_code('CRYPTO/UNSPECIFIED').response(sid)
      rescue KStor::MissingMessageArgument => e
        raise e
      rescue KStor::Error => e
        Log.info(e.message)
        e.response(sid)
      end

      private

      def handle_password_changed(req, resp, user)
        return unless resp.type == :user_password_changed

        @auth.handle_password_changed(req, resp, user)
      end

      def finish_response(resp)
        unless self.class.responds?(resp.class)
          raise UnknownResponseType, 'Unknown response type ' \
                                     "#{resp.type.inspect}"
        end
        resp
      end

      def controller_from_request_type(req)
        @controllers.each do |ctrl|
          return ctrl if ctrl.class.handles?(req)
        end

        raise Error.for_code('REQ/UNKNOWN', req.type)
      end
    end
  end
end
