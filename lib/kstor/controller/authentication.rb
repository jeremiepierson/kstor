# frozen_string_literal: true

require 'kstor/error'
require 'kstor/log'
require 'kstor/store'
require 'kstor/session'
require 'kstor/model'

module KStor
  module Controller
    # Specialized controller for user authentication and sessions.
    class Authentication
      # Create new auth controller.
      #
      # @param store [KStor::Store] data store where users are
      # @param session_store [KStor::SessionStore] where user sessions are
      # @return [KStor::Controller::Authentication] new auth controller
      def initialize(store, session_store)
        @store = store
        @sessions = session_store
      end

      # Authenticate request user.
      #
      # Request may either contain a login/password, or a session ID.
      #
      # @param req [KStor::Message::Request] client request
      # @return [KStor::Model::User] client user
      # @raise [KStor::InvalidSession] if session ID is invalid
      # @raise [KStor::UserNotAllowed] if user is not allowed
      # @raise [KStor::MissingLoginPassword] if database is empty and request
      #   only contains a session ID
      def authenticate(req)
        if @store.users?
          unlock_user(req)
        else
          create_first_user(req)
        end
      end

      # Check if user is allowed to access the application.
      #
      # @param user [KStor::Model::User] client user
      # @return [Boolean] true if login is allowed to access application data.
      def allowed?(user)
        user.status == 'new' || user.status == 'active'
      end

      private

      # Load user from database and decrypt private key and keychain.
      def unlock_user(req)
        if req.session?
          session_id = req.session_id
          user, secret_key = load_session(session_id)
        else
          user = load_user(req.login)
          secret_key = user.secret_key(req.password)
          session = Session.create(user, secret_key)
          @sessions << session
          session_id = session.id
        end
        user.unlock(secret_key)

        [user, session_id]
      end

      def load_session(sid)
        Log.debug("loading session #{sid}")
        session = @sessions[sid]
        raise Error.for_code('AUTH/BADSESSION', sid) unless session

        [session.user, session.secret_key]
      end

      def load_user(login)
        Log.debug("authenticating user #{login.inspect}")
        user = @store.user_by_login(login)
        Log.debug("loaded user ##{user.id} #{user.login}")
        unless user && allowed?(user)
          raise Error.for_code('AUTH/FORBIDDEN', login)
        end

        user
      end

      def create_first_user(req)
        raise Error.for_code('AUTH/MISSING') unless req.respond_to?(:login)

        Log.info("no user in database, creating #{req.login.inspect}")
        user = Model::User.new(
          login: req.login, name: req.login, status: 'new', keychain: {}
        )
        secret_key = user.secret_key(req.password)
        user.unlock(secret_key)
        user.id = @store.user_create(user)
        Log.info("user #{user.login} created")

        session = Session.create(user, secret_key)
        @sessions << session

        [user, session.id]
      end
    end
  end
end
