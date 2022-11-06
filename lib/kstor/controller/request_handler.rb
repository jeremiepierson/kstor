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

    # Request handler.
    class RequestHandler
      class << self
        attr_accessor :controllers

        def request_types
          @controllers.map(&:request_types).inject([], &:+)
        end

        def response_types
          ['error'] + @controllers.map(&:response_types).inject([], &:+)
        end

        def message_types
          request_types + response_types
        end

        def handles?(type)
          request_types.include?(type)
        end

        def responds?(type)
          response_types.include?(type)
        end
      end

      self.controllers = [Controller::User, Controller::Secret]

      def initialize(store, session_store)
        @auth = Controller::Authentication.new(store, session_store)
        @store = store
        @controllers = self.class.controllers.map do |klass|
          klass.new(store)
        end
      end

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
