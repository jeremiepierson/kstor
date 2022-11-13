# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'
require 'kstor/log'
require 'kstor/controller/base'

module KStor
  module Controller
    # Handle group related requests.
    class Group < Base
      request_type Message::GroupCreate
      request_type Message::GroupRename
      request_type Message::GroupDelete
      request_type Message::GroupSearch
      request_type Message::GroupGet
      request_type Message::GroupAddUser
      request_type Message::GroupRemoveUser

      response_type Message::GroupCreated
      response_type Message::GroupUpdated
      response_type Message::GroupDeleted
      response_type Message::GroupList
      response_type Message::GroupInfo

      private

      def handle_group_create(user, req)
        raise UserNotAllowed, user.login unless user.admin?

        group = group_create(user, req.name)
        args = {
          'group_id' => group.id,
          'group_name' => group.name,
          'group_pubk' => group.pubk
        }
        [Message::GroupCreated, args]
      end

      def handle_group_rename(user, req)
        raise UserNotAllowed, user.login unless user.admin?

        group_rename(req.group_id, req.name)
        [Message::GroupUpdated, { 'group_id' => req.group_id }]
      end

      def handle_group_delete(user, req)
        raise UserNotAllowed, user.login unless user.admin?

        group_delete(user, req.group_id)
        [Message::GroupDeleted, { 'group_id' => req.group_id }]
      end

      def handle_group_search(_user, req)
        groups = @store.groups.values.select do |g|
          File.fnmatch?(
            req.name, g.name, File::FNM_CASEFOLD | File::FNM_DOTMATCH
          )
        end
        [Message::GroupList, { 'groups' => groups.map(&:to_h) }]
      end

      def handle_group_get(_user, req)
        group = @store.groups[req.group_id]
        raise UnknownGroup, req.group_id unless group

        members = @store.group_members(req.group_id)
        args = {
          'id' => group.id,
          'name' => group.name,
          'members' => members.values.map(&:to_h)
        }
        [Message::GroupInfo, args]
      end

      def handle_group_add_user(user, req)
        raise UserNotAllowed, user.login unless user.admin?

        # Must be member of the target group (we need the group private key)
        keychain_item = user.keychain[req.group_id]
        raise UnknownGroupPrivateKey, req.group_id unless keychain_item

        group = @store.groups[req.group_id]
        group_add_user(keychain_item.privk, req.user_id, group)

        [Message::GroupUpdated, { 'group_id' => req.group_id }]
      end

      def handle_group_remove_user(user, req)
        raise UserNotAllowed, user.login unless user.admin?

        group = @store.groups[req.group_id]
        raise UnknownGroup, req.group_id unless group

        user = @store.users[req.user_id]
        raise UnknownUser, req.user_id unless user

        @store.group_remove_user(req.group_id, req.user_id)

        [Message::GroupUpdated, { 'group_id' => req.group_id }]
      end

      # ------- Below are utility methods not directly called from
      # ------- #handle_request

      def group_add_user(group_privk, target_user_id, group)
        target_user = @store.users[target_user_id]
        raise UnknownUser, target_user_id unless target_user

        keychain_item_create(target_user, group, group_privk)
      end

      def group_rename(group_id, new_name)
        group = @store.groups[group_id]
        raise UnknownGroup, group_id unless group

        @store.group_rename(group_id, new_name)
        Log.info(
          "Group ##{group_id} was renamed from #{group.name} to #{new_name}"
        )
      end

      def group_delete(user, group_id)
        group = @store.groups[group_id]
        raise UnknownGroup, group_id unless group

        members = @store.group_members(group_id)
        unless members.empty? || (members.size == 1 && members.key?(user.id))
          raise GroupHasMembers, group_id
        end

        @store.group_delete(group_id)
        Log.info("Group #{group.name} (##{group_id}) was deleted")
      end

      def group_create(user, name)
        pubk, privk = Crypto.generate_key_pair
        group_id = @store.group_create(name, pubk)
        group = Model::Group.new(id: group_id, name:, pubk:)
        keychain_item_create(user, group, privk)
        Log.info("Group #{name} created with ID #{group_id}")

        group
      end

      def keychain_item_create(user, group, group_privk)
        # Prepare a new keychain item for target user.
        target_keychain_item = Model::KeychainItem.new(
          group_id: group.id, group_pubk: group.pubk,
          privk: group_privk
        )
        # Encrypt group private key for target user.
        target_keychain_item.encrypt(user.pubk)
        # Store the damn thing.
        @store.keychain_item_create(
          user.id, group.id, target_keychain_item.encrypted_privk
        )
      end
    end
  end
end
