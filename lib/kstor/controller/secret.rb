# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'

module KStor
  # Handle secret-related requests.
  module SecretController
    def users
      @users ||= @store.users
    end

    def groups
      @groups ||= @store.groups
    end

    # in: metadata wildcards
    # needs: private key of one common group between user and secrets
    # out: array of:
    #   - secret id
    #   - secret metadata
    #   - secret metadata and value authors
    def secret_search(user, meta)
      return [] if user.keychain.empty?

      @store.secrets_for_user(user.id).select do |secret|
        group_privk = user.keychain[secret.group_id].privk
        author = users[secret.meta_author_id]
        secret.unlock_metadata(author.pubk, group_privk)
        secret.metadata.match?(meta)
      end
    end

    # in: secret_id
    # needs: private key of one common group between user and secret
    # out: plaintext
    def secret_unlock(user, secret_id)
      secret = @store.secret_fetch(secret_id, user.id)
      group_privk = user.keychain[secret.group_id].privk
      author = users[secret.value_author_id]
      secret.unlock(author.pubk, group_privk)

      group_privk = user.keychain[secret.group_id].privk
      author = users[secret.meta_author_id]
      secret.unlock_metadata(author.pubk, group_privk)

      secret
    end

    # in: plaintext, group ids, metadata
    # needs: encrypted metadata and ciphertext for each group
    # out: secret id
    def secret_create(user, plaintext, groups, meta)
      encrypted_data = {}
      Log.debug("secret_create: group_ids = #{groups.inspect}")
      groups.each do |g|
        encrypted_data[g.id] = [
          Crypto.encrypt_secret_value(g.pubk, user.privk, plaintext),
          Crypto.encrypt_secret_metadata(g.pubk, user.privk, meta.to_h)
        ]
      end
      @store.secret_create(user.id, encrypted_data)
    end

    # in: secret id, metadata
    # needs: every group public key for this secret, user private key
    # out: nil
    def secret_update_meta(user, secret, meta)
      group_ids = @store.groups_for_secret(secret.id)
      group_encrypted_metadata = group_ids.map do |group_id|
        group_pubk = groups[group_id].pubk
        author_privk = user.privk
        Crypto.encrypt_secret_metadata(group_pubk, author_privk, meta.to_h)
      end
      @store.secret_setmeta(secret.id, user.id, group_encrypted_metadata)
    end

    # in: secret id, plaintext
    # needs: every group public key for this secret, user private key
    # out: nil
    def secret_update_value(user, secret, plaintext)
      group_ids = @store.groups_for_secret(secret.id)
      group_ciphertexts = group_ids.map do |group_id|
        group_pubk = groups[group_id].pubk
        author_privk = user.privk
        Crypto.encrypt_secret_value(group_pubk, author_privk, plaintext)
      end
      @store.secret_setvalue(secret.id, user.id, group_ciphertexts)
    end

    # in: secret id
    # needs: nil
    # out: nil
    def delete(secret_id)
      @store.secret_delete(secret_id)
    end
  end
end
