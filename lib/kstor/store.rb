# frozen_string_literal: true

require 'kstor/sql_connection'
require 'kstor/model'
require 'kstor/log'

module KStor
  # Store and fetch objects in an SQLite database.
  # rubocop:disable Metrics/MethodLength
  class Store
    def initialize(file_path)
      @file_path = file_path
      @db = SQLConnection.new(file_path)
      @cache = {}
    end

    def transaction(&)
      @db.transaction(&)
    end

    def users?
      rows = @db.execute('SELECT count(*) AS n FROM users')
      count = Integer(rows.first['n'])
      Log.debug("store: count of users is #{count}")

      count.positive?
    end

    def user_create(user)
      @db.execute(<<-EOSQL, user.login, user.name, 'new')
        INSERT INTO users (login, name, status)
             VALUES (?, ?, ?)
      EOSQL
      user.id = @db.last_insert_row_id
      Log.debug("store: stored new user #{user.login}")
      params = [user.kdf_params, user.pubk, user.encrypted_privk].map(&:to_s)
      return user if params.any?(&:nil?)

      @db.execute(<<-EOSQL, user.id, *params)
        INSERT INTO users_crypto_data (user_id, kdf_params, pubk, encrypted_privk)
             VALUES (?, ?, ?, ?)
      EOSQL
      Log.debug("store: stored user crypto data for #{user.login}")

      user
    end

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

    def keychain_item_create(user_id, group_id, encrypted_privk)
      @db.execute(<<-EOSQL, user_id, group_id, encrypted_privk.to_s)
        INSERT INTO group_members (user_id, group_id, encrypted_privk)
             VALUES (?, ?, ?)
      EOSQL
    end

    def group_create(name, pubk)
      @db.execute(<<-EOSQL, name, pubk.to_s)
        INSERT INTO groups (name, pubk)
             VALUES (?, ?)
      EOSQL
      @db.last_insert_row_id
    end

    def groups
      return @cache[:groups] if @cache.key?(:groups)

      Log.debug('store: loading groups')
      rows = @db.execute(<<-EOSQL)
          SELECT id,
                 name,
                 pubk
            FROM groups
        ORDER BY name
      EOSQL
      @cache[:groups] = rows.to_h do |r|
        a = []
        a << r['id']
        a << Model::Group.new(
          id: r['id'], name: r['name'], pubk: Crypto::PublicKey.new(r['pubk'])
        )
        a
      end
    end

    def users
      return @cache[:users] if @cache.key?(:users)

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

      @cache[:users] = users_from_resultset(rows)
    end

    # in: login
    # out:
    #   - ID
    #   - name
    #   - status
    #   - public key
    #   - key derivation function parameters
    #   - encrypted private key
    #   - keychain: hash of:
    #     - group ID
    #     - encrypted group private key
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

    # in: user ID
    # out:
    #   - ID
    #   - name
    #   - status
    #   - public key
    #   - key derivation function parameters
    #   - encrypted private key
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

    # in: user ID
    # out: array of:
    #   - secret ID
    #   - group ID common between user and secret
    #   - secret encrypted metadata
    #   - secret value and metadata author IDs
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

    # in: secret ID, user ID
    # out: encrypted value
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

    # in:
    #   - user ID
    #   - hash of:
    #     - group ID
    #     - array of:
    #       - ciphertext
    #       - encrypted metadata
    # out: secret ID
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

    def groups_for_secret(secret_id)
      Log.debug("store: loading group IDs for secret #{secret_id}")
      rows = @db.execute(<<-EOSQL, secret_id)
          SELECT group_id
            FROM secret_values
           WHERE secret_id = ?
      EOSQL
      rows.map { |r| r['group_id'] }
    end

    # in: secret ID, author ID, array of [group ID, encrypted_metadata]
    # out: nil
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

    def user_from_resultset(rows, include_crypto_data: true)
      return nil if rows.empty?

      row = rows.shift
      user_data = {
        id: row['id'],
        login: row['login'],
        name: row['name'],
        status: row['status'],
        pubk: Crypto::PublicKey.new(row['pubk'])
      }
      include_crypto_data && user_crypto_data_from_resultset(user_data, row)
      Model::User.new(**user_data)
    end

    def user_crypto_data_from_resultset(user_data, row)
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
end
