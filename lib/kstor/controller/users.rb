# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'
require 'kstor/log'
require 'kstor/controller/base'

module KStor
  module Controller
    # Handle user related requests.
    class User < Base
      request_type Message::UserCreate
      request_type Message::UserActivate
      # request_type Message::UserRename
      # request_type Message::UserArchive
      # request_type Message::UserSetAdmin
      # request_type Message::UserUnsetAdmin
      request_type Message::UserChangePassword
      # request_type Message::UserResetPassword
      # request_type Message::UserSearch
      # request_type Message::UserView

      response_type Message::UserCreated
      response_type Message::UserUpdated
      response_type Message::UserPasswordChanged
      # response_type Message::UserList
      # response_type Message::UserInfo

      private

      def handle_user_create(user, req)
        raise UserNotAllowed, user.login unless user.admin?

        u, token = user_create(
          req.user_login, req.user_name, req.token_lifespan
        )
        Log.info("controller: created new user #{u.login}")
        args = {
          'user_id' => u.id,
          'activation_token' => token.to_h
        }
        [Message::UserCreated, args]
      end

      def handle_user_activate(user, req)
        raise Error.for_code('AUTH/MISSING') unless req.login_request?

        tk = @store.activation_token_get(user.id)
        raise Error.for_code('AUTH/MISSING') unless tk&.valid?

        user.secret_key(req.password)
        @store.user_activate(user)
        Log.info("controller: activated user #{user.login}")
        [Message::UserUpdated, { 'user_id' => user.id }]
      end

      def handle_user_change_password(user, req)
        raise Error.for_code('AUTH/MISSING') unless req.login_request?

        new_secret_key = user.secret_key(req.new_password)
        user.encrypt(new_secret_key)
        @store.user_update(user)
        Log.info("controller: changed password for user #{user.login}")
        [Message::UserPasswordChanged, { 'user_id' => user.id }]
      end

      # ------- Below are utility methods not directly called from
      # ------- #handle_request

      def user_create(login, name, token_lifespan)
        u = Model::User.new(
          login:, name:, status: 'new', keychain: {}
        )
        u.id = @store.user_create(u)
        token = Model::ActivationToken.create(u.id, token_lifespan)
        @store.activation_token_create(token)

        [u, token]
      end
    end
  end
end
