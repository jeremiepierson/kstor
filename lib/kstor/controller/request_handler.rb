# frozen_string_literal: true

require 'rbnacl'

require 'kstor/error'
require 'kstor/controller/authentication'
require 'kstor/controller/secret'
require 'kstor/controller/users'

module KStor
  module Controller
    # Request handler.
    class RequestHandler
      def initialize(store, session_store)
        @auth = Controller::Authentication.new(store, session_store)
        @secret = Controller::Secret.new(store)
        @user = Controller::User.new(store)
        @store = store
      end

      def handle_request(req)
        user, sid = @auth.authenticate(req)
        controller = controller_from_request_type(req)
        resp = @store.transaction { controller.handle_request(user, req) }
        user.lock
        resp.session_id = sid
        resp
      rescue RbNaClError => e
        Log.exception(e)
        Error.for_code('CRYPTO/UNSPECIFIED').response
      rescue Error => e
        Log.info(e.message)
        e.response
      end

      private

      def controller_from_request_type(req)
        case req.type
        when /^secret-(create|delete|search|unlock|update-(meta|value)?)$/
          @secret
        when /^group-create$/
          @user
        else
          raise Error.for_code('REQ/UNKNOWN', req.type)
        end
      end
    end
  end
end
