# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'
require 'kstor/controller/base'

module KStor
  class SecretNotFound < Error
    error_code 'SECRET/NOTFOUND'
    error_message 'Secret #%s not found.'
  end

  module Controller
    # Handle secret-related requests.
    class Secret < Base
      request_type Message::SecretCreate
      request_type Message::SecretSearch
      request_type Message::SecretUnlock
      request_type Message::SecretUpdateMeta
      request_type Message::SecretUpdateValue
      request_type Message::SecretDelete

      response_type Message::SecretCreated
      response_type Message::SecretList
      response_type Message::SecretValue
      response_type Message::SecretUpdated
      response_type Message::SecretDeleted

      private

      def handle_secret_create(user, req)
        meta = Model::SecretMeta.new(**req.meta)
        secret_groups = req.group_ids.map do |gid|
          @store.groups[gid.to_i]
        end
        args = {
          'secret_id' => create(user, req.plaintext, secret_groups, meta)
        }
        Message::SecretCreated.new(args)
      end

      def handle_secret_search(user, req)
        Log.debug("secretcontroller#handle_secret_search: #{req.args.inspect}")
        secrets = search(user, Model::SecretMeta.new(**req.meta))
        args = { 'secrets' => secrets.map { |s| s.to_h.except('group_id') } }
        Message::SecretList.new(args)
      end

      def handle_secret_unlock(user, req)
        secret = unlock(user, req.secret_id)
        args = unlock_format(secret)

        Message::SecretValue.new(args)
      end

      def handle_secret_update_meta(user, req)
        meta = Model::SecretMeta.new(req.meta)
        Log.debug("secret#handle_update_meta: meta=#{meta.to_h.inspect}")
        update_meta(user, req.secret_id, meta)
        Message::SecretUpdated.new({ 'secret_id' => req.secret_id })
      end

      def handle_secret_update_value(user, req)
        update_value(user, req.secret_id, req.plaintext)
        Message::SecretUpdated.new({ 'secret_id' => req.secret_id })
      end

      def handle_secret_delete(user, req)
        delete(user, req.secret_id)
        Message::SecretDeleted.new({ 'secret_id' => req.secret_id })
      end

      def users
        @store.users
      end

      def groups
        @store.groups
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
        secret = secret_fetch(secret_id, user.id)
        group_privk = user.keychain[secret.group_id].privk

        value_author = @store.users[secret.value_author_id]
        secret.unlock(value_author.pubk, group_privk)

        meta_author = @store.users[secret.meta_author_id]
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
        secret = secret_fetch(secret_id, user.id)
        unlock_metadata(user, secret)
        meta = secret.metadata.merge(partial_meta)
        group_ids = @store.groups_for_secret(secret.id)
        group_encrypted_metadata = group_ids.to_h do |group_id|
          group_pubk = @store.groups[group_id].pubk
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
      def update_value(user, secret_id, plaintext)
        secret = secret_fetch(secret_id, user.id)
        group_ids = @store.groups_for_secret(secret.id)
        group_ciphertexts = group_ids.to_h do |group_id|
          group_pubk = @store.groups[group_id].pubk
          author_privk = user.privk
          encrypted_value = Crypto.encrypt_secret_value(
            group_pubk, author_privk, plaintext
          )
          [group_id, encrypted_value]
        end
        @store.secret_setvalue(secret.id, user.id, group_ciphertexts)
      end

      # in: secret id
      # needs: nil
      # out: nil
      def delete(user, secret_id)
        # Check if user can see this secret:
        secret = secret_fetch(secret_id, user.id)
        raise Error.for_code('SECRET/NOTFOUND', secret_id) if secret.nil?

        @store.secret_delete(secret_id)
      end

      def unlock_format(secret)
        args = secret.to_h
        args['value_author'] = @store.users[secret.value_author_id].to_h
        args['metadata_author'] = @store.users[secret.meta_author_id].to_h

        group_ids = @store.groups_for_secret(secret.id)
        args['groups'] = @store.groups.values_at(*group_ids).map(&:to_h)

        args
      end

      def unlock_metadata(user, secret)
        group_privk = user.keychain[secret.group_id].privk
        author = @store.users[secret.meta_author_id]
        secret.unlock_metadata(author.pubk, group_privk)
      end

      def secret_fetch(secret_id, user_id)
        secret = @store.secret_fetch(secret_id, user_id)
        raise Error.for_code('SECRET/NOTFOUND', secret_id) if secret.nil?

        secret
      end
    end
  end
end
