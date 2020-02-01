# frozen_string_literal: true

require 'kstor/error'
require 'kstor/log'
require 'kstor/store'
require 'kstor/message'
require 'kstor/controller/secret'

module KStor
  # Error: user was not allowed to access application.
  class UserNotAllowed < Error
    error_code 'AUTH/FORBIDDEN'
    error_message 'User %s not allowed.'
  end

  # Error: unknown request type.
  class UnknownRequestType < Error
    error_code 'REQ/UNKNOWN'
    error_message 'Unknown request type %s'
  end

  # Request handler.
  class Controller
    include SecretController

    def initialize(store)
      @store = store
    end

    def handle_request(req)
      create_first_user(req) unless @store.users?
      method_name = method_name_from_request_type(req)

      unlock_user(req)
      @store.transaction { __send__(method_name, req) }
    rescue Error => e
      Log.info(e.message)
      e.response
    end

    def handle_secret_search(req)
      secrets = secret_search(SecretMeta.new(req.args))
      Response.new(
        'secret.list',
        'secrets' => secrets
      )
    end

    def handle_secret_unlock(req)
      plaintext = secret_unlock(req.args['secret_id'])
      Response.new('secret.value', 'plaintext' => plaintext)
    end

    def handle_secret_create(req)
      meta = SecretMeta.new(req.args['meta'])
      secret_id = secret_create(
        req.args['plaintext'], req.args['group_id'], meta
      )
      Response.new('secret.created', 'secret_id' => secret_id)
    end

    def handle_secret_updatemeta(req)
      meta = SecretMeta.new(req.args['meta'])
      secret_update_meta(req.args['secret_id'], meta)
      Response.new('secret.updated', 'secret_id' => req.args['secret_id'])
    end

    def handle_secret_updatevalue(req)
      secret_update_value(req.args['secret_id'], req.args['plaintext'])
      Response.new('secret.updated', 'secret_id' => req.args['secret_id'])
    end

    private

    # return true if login is allowed to access the database.
    def allowed?(user)
      user.status == :new || user.status == :active
    end

    def unlock_user(req)
      Log.debug("unlocking user #{req.login.inspect}")
      @user = @store.user_by_login(req.login)
      raise Error.for_code('AUTH/FORBIDDEN', login) unless allowed?(@user)

      @user.unlock(req.password)
    end

    def method_name_from_request_type(req)
      method_name = "handle_#{req.type.tr('.', '_')}".to_sym
      unless respond_to? method_name
        raise Error.for_code('REQ/UNKNOWN', req.type)
      end

      method_name
    end

    def create_first_user(req)
      admin = Model::User.new
      admin.login = req.login
      admin.name = req.login
      admin.status = 'new'
      @store.user_create(admin)
    end
  end
end
