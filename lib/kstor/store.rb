# frozen_string_literal: true

require 'mutex_m'

require 'kstor/sql_connection'
require 'kstor/model'
require 'kstor/log'

module KStor
  # Simplistic cache for list of users and groups.
  class StoreCache
    # Create new cache.
    def initialize
      @cache = {}
      @cache.extend(Mutex_m)
    end

    class << self
      # @!macro [new] dsl_storecache_property
      #   @!attribute $1
      #     @return returns cached list of $1

      # Declare a cached list of values.
      #
      # @param name [Symbol] name of list
      def property(name)
        define_method(name) do |&block|
          @cache.synchronize do
            return @cache[name] if @cache.key?(name)

            @cache[name] = block.call
          end
        end

        define_method("#{name}=".to_sym) do |list|
          @cache.synchronize { @cache[name] = list }
        end

        define_method("forget_#{name}") do
          @cache.synchronize { @cache.delete(name) }
        end
      end
    end

    # @!macro dsl_storecache_property
    property :users
    # @!macro dsl_storecache_property
    property :groups
  end

  # Store and fetch objects in an SQLite database.
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/ClassLength
  class Store
    # Create a new store backed by the given SQLite database file.
    #
    # @param file_path [String] path to SQLite database file
    # @return [KStor::Store] a data store
    def initialize(file_path)
      @file_path = file_path
      @db = SQLConnection.new(file_path)
      @cache = StoreCache.new
    end

    # Execute the given block in a database transaction.
    def transaction(&)
      @db.transaction(&)
    end

    # True if database contains any users.
    #
    # @return [Boolean] false if user table is empty
    def users?
      rows = @db.execute('SELECT count(*) AS n FROM users')
      count = Integer(rows.first['n'])
      Log.debug("store: count of users is #{count}")

      count.positive?
    end

    # Create a new user in database.
    #
    # @param user [KStor::Model::User] the user to create
    # @return [KStor::Model::User] the same user with a brand-new ID
    def user_create(user)
      @db.execute(<<-EOSQL, user.login, user.name, user.status)
        INSERT INTO users (login, name, status)
             VALUES (?, ?, ?)
      EOSQL
      user_id = @db.last_insert_row_id
      @cache.forget_users
      Log.debug("store: stored new user #{user.login}")
      params = [user.kdf_params, user.pubk, user.encrypted_privk]
      return user_id if params.any?(&:nil?)

      user_create_crypto(user_id, *params)
    end

    # Activate new user.
    def user_activate(user)
      user_create_crypto(
        user.id, user.kdf_params, user.pubk, user.encrypted_privk
      )
      user.status = 'active'
      user_set_status(user.id, user.status)
      activation_tokens_purge
      @cache.forget_users

      user
    end

    # Store KDF parameters, public key and encrypted private key for user.
    def user_create_crypto(user_id, kdf_params, pubk, encrypted_privk)
      params = [kdf_params, pubk, encrypted_privk]
      @db.execute(<<-EOSQL, user_id, *params.map(&:to_s))
        INSERT INTO users_crypto_data (user_id, kdf_params, pubk, encrypted_privk)
             VALUES (?, ?, ?, ?)
      EOSQL
      Log.debug("store: stored user crypto data for user ##{user_id}")
      @cache.forget_users

      user_id
    end

    # Update user status.
    def user_set_status(user_id, status)
      @db.execute(<<-EOSQL, status, user_id)
        UPDATE users SET status = ? WHERE id = ?
      EOSQL
    end

    # Insert a new activation token.
    def activation_token_create(token)
      insert_args = [
        token.user_id, token.token, token.not_before, token.not_after
      ]
      @db.execute(<<-EOSQL, *insert_args)
        INSERT INTO user_activations (user_id, token, not_before, not_after)
             VALUES (?, ?, ?, ?)
      EOSQL
      Log.debug("store: saved token for user ##{token.user_id}")
    end

    # Load user activation token.
    #
    # @param user_id [Integer] user ID
    def activation_token_get(user_id)
      rows = @db.execute(<<-EOSQL, user_id)
        SELECT user_id, token, not_before, not_after
          FROM user_activations
         WHERE user_id = ?
      EOSQL
      return nil if rows.empty?

      r = rows.shift
      Model::ActivationToken.new(
        user_id: r['user_id'], token: r['token'],
        not_before: r['not_before'], not_after: r['not_after']
      )
    end

    # Delete outdated user action tokens.
    #
    # Tokens are invalid if they are expired or if they were redeemed to
    # activate a user.
    def activation_tokens_purge
      now = Time.now.to_i
      @db.execute(<<-EOSQL, now)
        DELETE FROM user_activations
              WHERE user_id IN (SELECT id FROM users WHERE status <> 'new')
                 OR not_after > ?
      EOSQL
    end

    # Update user name, status and keychain.
    #
    # @param user [KStor::Model::User] user to modify.
    def user_update(user)
      @db.execute(<<-EOSQL, user.name, user.status, user.id)
        UPDATE users SET name = ?, status = ?
         WHERE id = ?
      EOSQL
      params = [user.kdf_params, user.pubk, user.encrypted_privk, user.id]
      @db.execute(<<-EOSQL, *params)
        UPDATE users_crypto_data SET
               kdf_params = ?,
               pubk = ?
               encrypted_params = ?
         WHERE user_id = ?
      EOSQL
    end

    # Add a group private key to a user keychain.
    #
    # @param user_id [Integer] ID of an existing user
    # @param group_id [Integer] ID of an existing group
    # @param encrypted_privk [KStor::Crypto::ArmoredValue] group private key
    #   encrypted with user public key
    def keychain_item_create(user_id, group_id, encrypted_privk)
      @db.execute(<<-EOSQL, user_id, group_id, encrypted_privk.to_s)
        INSERT INTO group_members (user_id, group_id, encrypted_privk)
             VALUES (?, ?, ?)
      EOSQL
    end

    # Create a new group.
    #
    # Note that it doesn't store the group private key, as it must only exist
    # in users keychains.
    #
    # @param name [String] Name of the new group (must be unique in database)
    # @param pubk [KStor::Crypto::PublicKey] group public key
    # @return [Integer] ID of the new group
    def group_create(name, pubk)
      @db.execute(<<-EOSQL, name, pubk.to_s)
        INSERT INTO groups (name, pubk)
             VALUES (?, ?)
      EOSQL
      @cache.forget_groups
      @db.last_insert_row_id
    end

    # Rename an existing group.
    #
    # @param group_id [Integer] ID of group to be renamed
    # @param new_name [String] new name of group
    def group_rename(group_id, new_name)
      @db.execute(<<-EOSQL, new_name, group_id)
        UPDATE groups SET name = ?
         WHERE id = ?
      EOSQL
      @cache.forget_groups
    end

    # List all users in a group.
    def group_members(group_id)
      rows = @db.execute(<<-EOSQL, group_id)
             SELECT u.id,
                    u.login,
                    u.name,
                    u.status,
                    c.pubk
               FROM users u
          LEFT JOIN users_crypto_data c ON (c.user_id = u.id)
          LEFT JOIN group_members g ON (g.user_id = u.id)
              WHERE g.group_id = ?
           ORDER BY u.id
      EOSQL
      users_from_resultset(rows)
    end

    # Delete a group
    def group_delete(group_id)
      @db.execute('DELETE FROM groups WHERE id = ?', group_id)
      @cache.forget_groups
    end

    # Add user to group
    def group_add_user(group_id, user_id, encrypted_group_privk)
      @db.execute(<<-EOSQL, group_id, user_id, encrypted_group_privk.to_s)
        INSERT INTO group_members (group_id, user_id, encrypted_privk)
             VALUES (?, ?, ?)
      EOSQL
      @cache.forget_users
    end

    # Remove user from group
    def group_remove_user(group_id, user_id)
      @db.execute(<<-EOSQL, group_id, user_id)
        DELETE FROM group_members
              WHERE group_id = ?
                AND user_id = ?
      EOSQL
      @cache.forget_users
    end

    # List all groups.
    #
    # Note that this list is cached in memory, so calling this method multiple
    # times should be cheap.
    #
    # @return [Hash[Integer, KStor::Model::Group]] a list of all groups in
    #   database
    def groups
      @cache.groups do
        Log.debug('store: loading groups')
        rows = @db.execute(<<-EOSQL)
            SELECT id,
                   name,
                   pubk
              FROM groups
          ORDER BY name
        EOSQL
        rows.to_h do |r|
          a = []
          a << r['id']
          a << Model::Group.new(
            id: r['id'], name: r['name'], pubk: Crypto::PublicKey.new(r['pubk'])
          )
          a
        end
      end
    end

    # List all users.
    #
    # Note that this list is cached in memory, so calling this method multiple
    # times should be cheap.
    #
    # @return [Hash[Integer, KStor::Model::User]] a list of all users in
    #   database
    def users
      @cache.users do
        Log.debug('store: loading users')
        rows = @db.execute(<<-EOSQL)
             SELECT u.id,
                    u.login,
                    u.name,
                    u.status,
                    c.pubk
               FROM users u
          LEFT JOIN users_crypto_data c ON (c.user_id = u.id)
           ORDER BY u.login
        EOSQL

        users_from_resultset(rows)
      end
    end

    # Lookup user by login.
    #
    # @param login [String] User login
    # @return [KStor::Model::User, nil] a user object instance with encrypted
    #   private data, or nil if login was not found in database.
    def user_by_login(login)
      Log.debug("store: loading user by login #{login.inspect}")
      rows = @db.execute(<<-EOSQL, login)
           SELECT u.id,
                  u.login,
                  u.name,
                  u.status,
                  c.kdf_params,
                  c.pubk,
                  c.encrypted_privk
             FROM users u
        LEFT JOIN users_crypto_data c ON (c.user_id = u.id)
            WHERE u.login = ?
      EOSQL
      user_from_resultset(rows, include_crypto_data: true)
    end

    # Lookup user by ID.
    #
    # @param user_id [Integer] User ID
    # @return [KStor::Model::User, nil] a user object instance with encrypted
    #   private data, or nil if login was not found in database.
    def user_by_id(user_id)
      Log.debug("store: loading user by ID ##{user_id}")
      rows = @db.execute(<<-EOSQL, user_id)
           SELECT u.id,
                  u.login,
                  u.name,
                  u.status,
                  c.kdf_params,
                  c.pubk,
                  c.encrypted_privk,
             FROM users u
        LEFT JOIN users_crypto_data c ON (c.user_id = u.id)
            WHERE u.id = ?
      EOSQL
      user_from_resultset(rows, include_crypto_data: true)
    end

    # List of all secrets that should be readable by a user.
    #
    # @param user_id [Integer] ID of user that will read the secrets
    # @return [Array[KStor::Model::Secret]] A list of secrets, that may be
    #   empty.
    def secrets_for_user(user_id)
      Log.debug("store: loading secrets for user ##{user_id}")
      rows = @db.execute(<<-EOSQL, user_id)
           SELECT s.id,
                  s.value_author_id,
                  s.meta_author_id,
                  sv.group_id,
                  sv.ciphertext,
                  sv.encrypted_metadata
             FROM secrets s,
                  secret_values sv,
                  group_members gm
            WHERE gm.user_id = ?
              AND gm.group_id = sv.group_id
              AND sv.secret_id = s.id
         GROUP BY s.id
         ORDER BY s.id, sv.group_id
      EOSQL

      rows.map { |r| secret_from_row(r) }
    end

    # Fetch one secret by it's ID.
    #
    # @param secret_id [Integer] ID of secret
    # @param user_id [Integer] ID of secret reader
    # @return [KStor::Model::Secret, nil] A secret, or nil if secret_id was not
    #   found or user_id can't read it.
    def secret_fetch(secret_id, user_id)
      Log.debug(
        "store: loading secret value ##{secret_id} for user ##{user_id}"
      )
      rows = @db.execute(<<-EOSQL, user_id, secret_id)
           SELECT s.id,
                  s.value_author_id,
                  s.meta_author_id,
                  sv.group_id,
                  sv.ciphertext,
                  sv.encrypted_metadata
             FROM secrets s,
                  secret_values sv,
                  group_members gm
            WHERE gm.user_id = ?
              AND gm.group_id = sv.group_id
              AND sv.secret_id = ?
              AND s.id = sv.secret_id
      EOSQL
      return nil if rows.empty?

      secret_from_row(rows.first)
    end

    # Create a new secret.
    #
    # Encrypted data should be a map of group_id to encrypted data for this
    # group's key pair as a two-value array, first metadata and then value.
    #
    # @param author_id [Integer] ID of user that creates the new secret
    # @param encrypted_data
    #   [Array[Hash[Integer, Array[KStor::Crypto::ArmoredValue]]]] see above
    #   description for shape of value.
    # @return [Integer] ID of new secret
    def secret_create(author_id, encrypted_data)
      Log.debug("store: creating secret for user #{author_id}")
      @db.execute(<<-EOSQL, author_id, author_id)
        INSERT INTO secrets (value_author_id, meta_author_id) VALUES (?, ?)
      EOSQL
      secret_id = @db.last_insert_row_id
      encrypted_data.each do |group_id, (ciphertext, encrypted_metadata)|
        secret_value_create(secret_id, group_id, ciphertext, encrypted_metadata)
      end

      secret_id
    end

    # List of group IDs that can read this secret.
    #
    # @param secret_id [Integer] ID of secret
    # @return [Array[KStor::Model::Group]] list of group ids
    def groups_for_secret(secret_id)
      Log.debug("store: loading group IDs for secret #{secret_id}")
      rows = @db.execute(<<-EOSQL, secret_id)
          SELECT group_id
            FROM secret_values
           WHERE secret_id = ?
      EOSQL
      rows.map { |r| r['group_id'] }
    end

    # Overwrite secret metadata.
    #
    # @param secret_id [Integer] ID of secret to update
    # @param user_id [Integer] ID of user that changes metadata
    # @param group_encrypted_metadata
    #   [Array[Hash[Integer, KStor::Crypt::ArmoredValue]]] map of group IDs to
    #   encrypted metadata.
    def secret_setmeta(secret_id, user_id, group_encrypted_metadata)
      Log.debug("store: set metadata for secret ##{secret_id}")
      @db.execute(<<-EOSQL, user_id, secret_id)
        UPDATE secrets SET meta_author_id = ? WHERE id = ?
      EOSQL
      group_encrypted_metadata.each do |group_id, encrypted_metadata|
        @db.execute(<<-EOSQL, encrypted_metadata.to_s, secret_id, group_id)
          UPDATE secret_values
             SET encrypted_metadata = ?
           WHERE secret_id = ?
             AND group_id = ?
        EOSQL
      end
    end

    # Overwrite secret value.
    #
    # @param secret_id [Integer] ID of secret to update
    # @param user_id [Integer] ID of user that changes the value
    # @param group_ciphertexts
    #   [Array[Hash[Integer, KStor::Crypt::ArmoredValue]]] map of group IDs to
    #   encrypted values.
    def secret_setvalue(secret_id, user_id, group_ciphertexts)
      Log.debug("store: set value for secret ##{secret_id}")
      @db.execute(<<-EOSQL, user_id, secret_id)
        UPDATE secrets SET value_author_id = ? WHERE id = ?
      EOSQL
      group_ciphertexts.each do |group_id, ciphertext|
        @db.execute(<<-EOSQL, ciphertext.to_s, secret_id, group_id)
          UPDATE secret_values
             SET ciphertext = ?
           WHERE secret_id = ?
             AND group_id = ?
        EOSQL
      end
    end

    # Delete a secrete from database.
    #
    # @param secret_id [Integer] ID of secret
    def secret_delete(secret_id)
      Log.debug("store: delete secret ##{secret_id}")
      # Will cascade to secret_values:
      @db.execute(<<-EOSQL, secret_id)
        DELETE FROM secrets WHERE id = ?
      EOSQL
    end

    private

    # in: secret ID, group ID, encrypted metadata and value
    # out: nil
    def secret_value_create(secret_id, group_id, ciphertext, encrypted_metadata)
      params = [ciphertext.to_s, encrypted_metadata.to_s]
      @db.execute(<<-EOSQL, secret_id, group_id, *params)
        INSERT INTO secret_values (
          secret_id, group_id,
          ciphertext, encrypted_metadata
        ) VALUES (
          ?, ?,
          ?, ?
        )
      EOSQL
    end

    def users_from_resultset(rows)
      users = []
      while (u = user_from_resultset(rows, include_crypto_data: false))
        users << u
      end

      users.to_h { |uu| [uu.id, uu] }
    end

    # Create a new instance of {KStor::Model::User} from a query result rows.
    #
    # This will shift (consume) one row from provided array.
    #
    # @param rows [Array[Hash[String, Any]]] Array of query result rows
    # @param include_crypto_data [Boolean] true if new user object should have
    #   encrypted private key data and keychain
    # @return [Array[KStor::Model], nil] A new user object, or nil if there
    #   were no more rows
    def user_from_resultset(rows, include_crypto_data: true)
      return nil if rows.empty?

      row = rows.shift
      user_data = {
        id: row['id'],
        login: row['login'],
        name: row['name'],
        status: row['status'],
        pubk: row['pubk'] ? Crypto::PublicKey.new(row['pubk']) : nil
      }
      include_crypto_data && user_crypto_data_from_resultset(user_data, row)
      Model::User.new(**user_data)
    end

    def user_crypto_data_from_resultset(user_data, row)
      return unless row['kdf_params'] && row['encrypted_privk']

      user_data.merge!(
        kdf_params: Crypto::KDFParams.new(row['kdf_params']),
        encrypted_privk: Crypto::ArmoredValue.new(row['encrypted_privk']),
        keychain: keychain_fetch(row['id'])
      )
    end

    # in: user ID
    # out: hash of:
    #   - group ID
    #   - encrypted_private key
    def keychain_fetch(user_id)
      rows = @db.execute(<<-EOSQL, user_id)
           SELECT g.id,
                  g.pubk,
                  gm.encrypted_privk
             FROM groups g,
                  group_members gm
            WHERE gm.user_id = ?
              AND gm.group_id = g.id
         ORDER BY g.name
      EOSQL
      rows.to_h do |r|
        [
          r['id'],
          Model::KeychainItem.new(
            group_id: r['id'],
            group_pubk: Crypto::PublicKey.new(r['pubk']),
            encrypted_privk: Crypto::ArmoredValue.new(r['encrypted_privk'])
          )
        ]
      end
    end

    def secret_from_row(row)
      Model::Secret.new(
        id: row['id'],
        value_author_id: row['value_author_id'],
        meta_author_id: row['meta_author_id'],
        group_id: row['group_id'],
        ciphertext: Crypto::ArmoredValue.new(row['ciphertext']),
        encrypted_metadata: Crypto::ArmoredValue.new(row['encrypted_metadata'])
      )
    end
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/ClassLength
end
