# frozen_string_literal: true

require 'kstor/error'
require 'kstor/log'
require 'kstor/store'
require 'kstor/message'
require 'kstor/controller/secret'
require 'kstor/controller/users'

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

  # Error: missing request argument.
  class MissingArgument < Error
    error_code 'REQ/MISSINGARG'
    error_message 'Missing argument %s for request type %s'
  end

  # Request handler.
  class Controller
    include UserController
    include SecretController

    def initialize(store)
      @store = store
    end

    def handle_request(req)
      method_name = method_name_from_request_type(req)
      @store.users? ? unlock_user(req) : create_first_user(req)
      @store.transaction { __send__(method_name, req) }
    rescue RbNaClError => e
      Log.exception(e)
      Error.for_code('CRYPTO/UNSPECIFIED').response
    rescue Error => e
      Log.info(e.message)
      e.response
    end

    def handle_group_create(req)
      unless req.args['name']
        raise Error.for_code('REQ/MISSINGARG', 'name', req.type)
      end

      group = group_create(req.args['name'])
      Response.new(
        'group.created',
        'group_id' => group.id,
        'group_name' => group.name
      )
    end

    def handle_secret_search(req)
      secrets = secret_search(Model::SecretMeta.new(**req.args))
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
      meta = Model::SecretMeta.new(**req.args['meta'])
      secret_groups = req.args['group_ids'].map { |gid| groups[gid] }
      secret_id = secret_create(
        req.args['plaintext'], secret_groups, meta
      )
      Response.new('secret.created', 'secret_id' => secret_id)
    end

    def handle_secret_updatemeta(req)
      meta = Model::SecretMeta.new(req.args['meta'])
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
      user.status == 'new' || user.status == 'active'
    end

    def unlock_user(req)
      Log.debug("unlocking user #{req.login.inspect}")
      @user = @store.user_by_login(req.login)
      Log.debug("loaded user #{@user.inspect}")
      unless @user && allowed?(@user)
        raise Error.for_code('AUTH/FORBIDDEN', req.login)
      end

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
      Log.info("no user in database, creating #{req.login.inspect}")
      @user = Model::User.new(
        login: req.login,
        name: req.login,
        status: 'new',
        keychain: {}
      )
      @user.unlock(req.password)
      @store.user_create(@user)
      Log.info("user #{@user.login} created")
    end
  end
end
