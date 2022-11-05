# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'
require 'kstor/log'

module KStor
  module Controller
    # Handle user and group related requests.
    class User
      def initialize(store)
        @store = store
      end

      def handle_request(user, req)
        case req.type
        when /^group-create$/ then handle_group_create(user, req)
        end
      end

      private

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

      def group_create(user, name)
        pubk, privk = Crypto.generate_key_pair
        group_id = @store.group_create(name, pubk)
        encrypted_privk = Crypto.encrypt_group_privk(
          user.pubk, privk
        )
        Log.debug("encrypted_privk = #{encrypted_privk}")
        keychain_item_create(user, group_id, pubk, encrypted_privk)

        Model::Group.new(id: group_id, name:, pubk:)
      end

      def keychain_item_create(user, group_id, pubk, encrypted_privk)
        item = Model::KeychainItem.new(
          group_id:,
          group_pubk: pubk,
          encrypted_privk:
        )
        user.keychain[item.group_id] = item
        @store.keychain_item_create(user.id, group_id, encrypted_privk)
      end
    end
  end
end
