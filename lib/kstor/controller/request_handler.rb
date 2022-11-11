# frozen_string_literal: true

require 'rbnacl'

require 'kstor/error'
require 'kstor/controller/authentication'
require 'kstor/controller/secret'
require 'kstor/controller/users'

module KStor
  module Controller
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
          ['error'] + @controllers.map(&:response_types).inject([], &:+)
        end

        # All message types handled and produced by this controller.
        #
        # @return [Array[String]] List of all message types
        def message_types
          request_types + response_types
        end

        # True if this controller can handle this request type.
        #
        # @param [String] request type
        # @return [Boolean] true if handled
        def handles?(type)
          request_types.include?(type)
        end

        # True if this controller can respond to a client with this type of
        # reponse.
        #
        # @param [String] response type
        # @return [Boolean] true if can be produced.
        def responds?(type)
          response_types.include?(type)
        end
      end

      self.controllers = [Controller::User, Controller::Secret]

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
      # @param req [KStor::LoginRequest, KStor::SessionRequest] client request
      # @return [KStor::Response] server response
      def handle_request(req)
        user, sid = @auth.authenticate(req)
        controller = controller_from_request_type(req)
        resp = @store.transaction { controller.handle_request(user, req) }
        user.lock
        finish_response(resp, sid)
      rescue RbNaClError => e
        Log.exception(e)
        Error.for_code('CRYPTO/UNSPECIFIED').response
      rescue Error => e
        Log.info(e.message)
        e.response
      end

      private

      def finish_response(resp, sid)
        unless self.class.responds?(resp.type)
          raise UnknownResponseType, 'Unknown response type ' \
                                     "#{resp.type.inspect}"
        end

        resp.session_id = sid
        resp
      end

      def controller_from_request_type(req)
        @controllers.each do |ctrl|
          return ctrl if ctrl.class.handles?(req.type)
        end

        raise Error.for_code('REQ/UNKNOWN', req.type)
      end
    end
  end
end
