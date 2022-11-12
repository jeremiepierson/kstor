# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'
require 'kstor/log'
require 'kstor/controller/base'

module KStor
  module Controller
    # Handle user and group related requests.
    class User < Base
      request_type Message::GroupCreate
      # request_type Message::GroupRename
      # request_type Message::GroupDelete
      # request_type Message::GroupAddUser
      # request_type Message::GroupRemoveUser
      # request_type Message::GroupSearch
      # request_type Message::GroupView
      # request_type Message::UserCreate
      # request_type Message::UserRename
      # request_type Message::UserArchive
      # request_type Message::UserSetAdmin
      # request_type Message::UserUnsetAdmin
      # request_type Message::UserChangePassword
      # request_type Message::UserResetPassword
      # request_type Message::UserSearch
      # request_type Message::UserView

      response_type Message::GroupCreated
      # response_type Message::GroupUpdated
      # response_type Message::GroupDeleted
      # response_type Message::GroupList
      # response_type Message::GroupInfo
      # response_type Message::UserCreated
      # response_type Message::UserUpdated
      # response_type Message::UserList
      # response_type Message::UserInfo

      private

      def handle_group_create(user, req)
        group = group_create(user, req.name)
        args = {
          group_id: group.id,
          group_name: group.name,
          group_pubk: group.pubk
        }
        [Message::GroupCreated, args]
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
