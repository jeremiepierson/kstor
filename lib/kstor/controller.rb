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

  # Request handler.
  class Controller
    include UserController
    include SecretController

    def initialize(store, session_store)
      @store = store
      @sessions = session_store
    end

    def handle_request(req)
      method_name = method_name_from_request_type(req)
      user, sid = @store.users? ? unlock_user(req) : create_first_user(req)
      resp = @store.transaction { __send__(method_name, user, req) }
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

    def handle_group_create(user, req)
      unless req.args['name']
        raise Error.for_code('REQ/MISSINGARG', 'name', req.type)
      end

      group = group_create(user, req.args['name'])
      @groups = nil
      Response.new(
        'group.created',
        'group_id' => group.id,
        'group_name' => group.name,
        'group_pubk' => group.pubk
      )
    end

    def handle_secret_search(user, req)
      secrets = secret_search(user, Model::SecretMeta.new(**req.args))
      args = secrets.map do |s|
        h = s.to_h
        h.delete('group_id')
        h
      end
      Response.new(
        'secret.list',
        { 'secrets' => args }
      )
    end

    def handle_secret_unlock(user, req)
      secret_id = req.args['secret_id']
      secret = secret_unlock(user, secret_id)
      args = secret_unlock_format(secret)

      Response.new('secret.value', **args)
    end

    def handle_secret_create(user, req)
      meta = Model::SecretMeta.new(**req.args['meta'])
      secret_groups = req.args['group_ids'].map { |gid| groups[gid.to_i] }
      secret_id = secret_create(
        user, req.args['plaintext'], secret_groups, meta
      )
      Response.new('secret.created', 'secret_id' => secret_id)
    end

    def handle_secret_updatemeta(user, req)
      meta = Model::SecretMeta.new(req.args['meta'])
      secret_update_meta(user, req.args['secret_id'], meta)
      Response.new('secret.updated', 'secret_id' => req.args['secret_id'])
    end

    def handle_secret_updatevalue(user, req)
      secret_update_value(user, req.args['secret_id'], req.args['plaintext'])
      Response.new('secret.updated', 'secret_id' => req.args['secret_id'])
    end

    private

    def secret_unlock_format(secret)
      args = secret.to_h
      args['value_author'] = users[secret.value_author_id].to_h
      args['metadata_author'] = users[secret.meta_author_id].to_h

      group_ids = @store.groups_for_secret(secret_id)
      args['groups'] = groups.values_at(*group_ids).map(&:to_h)

      args
    end

    # return true if login is allowed to access the database.
    def allowed?(user)
      user.status == 'new' || user.status == 'active'
    end

    def unlock_user(req)
      if req.respond_to?(:session_id)
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

    def method_name_from_request_type(req)
      method_name = "handle_#{req.type.tr('.', '_')}".to_sym
      unless respond_to? method_name
        raise Error.for_code('REQ/UNKNOWN', req.type)
      end

      method_name
    end

    def create_first_user(req)
      raise Error.for_code('AUTH/MISSING') unless req.respond_to?(:login)

      Log.info("no user in database, creating #{req.login.inspect}")
      user = Model::User.new(
        login: req.login, name: req.login, status: 'new', keychain: {}
      )
      secret_key = user.secret_key(req.password)
      user.unlock(secret_key)
      @store.user_create(user)
      Log.info("user #{user.login} created")

      session = Session.create(user, secret_key)
      @sessions << session

      [user, session.id]
    end
  end
end
