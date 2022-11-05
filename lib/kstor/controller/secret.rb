# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'

module KStor
  module Controller
    # Handle secret-related requests.
    class Secret
      def initialize(store)
        @store = store
      end

      def handle_request(user, req)
        case req.type
        when 'secret-create' then handle_create(user, req)
        when 'secret-search' then handle_search(user, req)
        when 'secret-unlock' then handle_unlock(user, req)
        when 'secret-update-meta' then handle_update_meta(user, req)
        when 'secret-update-value' then handle_update_value(user, req)
        else
          raise Error.for_code('REQ/UNKNOWN', req.type)
        end
      end

      private

      def handle_create(user, req)
        meta = Model::SecretMeta.new(**req.args['meta'])
        secret_groups = req.args['group_ids'].map { |gid| groups[gid.to_i] }
        secret_id = create(
          user, req.args['plaintext'], secret_groups, meta
        )
        Response.new('secret.created', 'secret_id' => secret_id)
      end

      def handle_search(user, req)
        secrets = search(user, Model::SecretMeta.new(**req.args))
        args = secrets.map do |s|
          h = s.to_h
          h.delete('group_id')
          h
        end
        Response.new(
          'secret.list',
          'secrets' => args
        )
      end

      def handle_unlock(user, req)
        secret_id = req.args['secret_id']
        secret = unlock(user, secret_id)
        args = unlock_format(secret)

        Response.new('secret.value', **args)
      end

      def handle_update_meta(user, req)
        meta = Model::SecretMeta.new(req.args['meta'])
        Log.debug("secret#handle_update_meta: meta=#{meta.to_h.inspect}")
        update_meta(user, req.args['secret_id'], meta)
        Response.new('secret.updated', 'secret_id' => req.args['secret_id'])
      end

      def handle_update_value(user, req)
        update_value(user, req.args['secret_id'], req.args['plaintext'])
        Response.new('secret.updated', 'secret_id' => req.args['secret_id'])
      end

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
      def search(user, meta)
        return [] if user.keychain.empty?

        @store.secrets_for_user(user.id).select do |secret|
          unlock_metadata(user, secret)
          secret.metadata.match?(meta)
        end
      end

      # in: secret_id
      # needs: private key of one common group between user and secret
      # out: plaintext
      def unlock(user, secret_id)
        secret = @store.secret_fetch(secret_id, user.id)
        group_privk = user.keychain[secret.group_id].privk

        value_author = users[secret.value_author_id]
        secret.unlock(value_author.pubk, group_privk)

        meta_author = users[secret.meta_author_id]
        secret.unlock_metadata(meta_author.pubk, group_privk)

        secret
      end

      # in: plaintext, group ids, metadata
      # needs: encrypted metadata and ciphertext for each group
      # out: secret id
      def create(user, plaintext, groups, meta)
        encrypted_data = {}
        Log.debug("secret#create: group_ids = #{groups.inspect}")
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
      def update_meta(user, secret_id, partial_meta)
        secret = @store.secret_fetch(secret_id, user.id)
        unlock_metadata(user, secret)
        meta = secret.metadata.merge(partial_meta)
        group_ids = @store.groups_for_secret(secret.id)
        group_encrypted_metadata = group_ids.to_h do |group_id|
          group_pubk = groups[group_id].pubk
          author_privk = user.privk
          encrypted_meta = Crypto.encrypt_secret_metadata(
            group_pubk, author_privk, meta.to_h
          )
          [group_id, encrypted_meta]
        end
        @store.secret_setmeta(secret.id, user.id, group_encrypted_metadata)
      end

      # in: secret id, plaintext
      # needs: every group public key for this secret, user private key
      # out: nil
      def update_value(user, secret, plaintext)
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

      def unlock_format(secret)
        args = secret.to_h
        args['value_author'] = users[secret.value_author_id].to_h
        args['metadata_author'] = users[secret.meta_author_id].to_h

        group_ids = @store.groups_for_secret(secret.id)
        args['groups'] = groups.values_at(*group_ids).map(&:to_h)

        args
      end

      def unlock_metadata(user, secret)
        group_privk = user.keychain[secret.group_id].privk
        author = users[secret.meta_author_id]
        secret.unlock_metadata(author.pubk, group_privk)
      end
    end
  end
end
