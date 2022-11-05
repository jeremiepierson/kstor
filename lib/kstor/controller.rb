# frozen_string_literal: true

require 'kstor/error'
require 'kstor/log'
require 'kstor/store'
require 'kstor/message'
require 'kstor/controller/authentication'
require 'kstor/controller/secret'
require 'kstor/controller/users'

module KStor
  # Error: user was not allowed to access application.
  class UserNotAllowed < Error
    error_code 'AUTH/FORBIDDEN'
    error_message 'User %s not allowed.'
  end

  # Error: invalid session ID
  class InvalidSession < Error
    error_code 'AUTH/BADSESSION'
    error_message 'Invalid session ID %s'
  end

  class MissingLoginPassword < Error
    error_code 'AUTH/MISSING'
    error_message 'Missing login and password'
  end

  # Error: unknown request type.
  class UnknownRequestType < Error
    error_code 'REQ/UNKNOWN'
    error_message 'Unknown request type %s'
  end

  # Error: missing request argument.
  class MissingArgument < Error
    error_code 'REQ/MISSINGARG'
    error_message 'Missing argument %s for request type %s'
  end

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
        when /^secret-(create|search|unlock|update(meta)?)$/
          @secret
        when /^group_create$/
          @user
        else
          raise Error.for_code('REQ/UNKNOWN', req.type)
        end
      end
    end
  end
end
