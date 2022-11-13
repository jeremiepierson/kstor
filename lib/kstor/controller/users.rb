# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'
require 'kstor/log'
require 'kstor/controller/base'

module KStor
  class UnknownGroup < KStor::Error
    error_code 'STORE/UNKNOWNGROUP'
    error_message 'Unknown group with ID #%d'
  end

  class UnknownUser < KStor::Error
    error_code 'STORE/UNKNOWNUSER'
    error_message 'Unknown user with ID #%d'
  end

  class GroupHasMembers < KStor::Error
    error_code 'STORE/GROUPHASMEMBERS'
    error_message "Group #%d has members and can't be deleted"
  end

  class UnknownGroupPrivateKey < KStor::Error
    error_code 'STORE/UNKNOWNGROUPPRIVK'
    error_message "Current user doesn't have access to private key of group #%d"
  end

  module Controller
    # Handle user and group related requests.
    class User < Base
      request_type Message::GroupCreate
      request_type Message::GroupRename
      request_type Message::GroupDelete
      request_type Message::GroupSearch
      request_type Message::GroupGet
      request_type Message::GroupAddUser
      request_type Message::GroupRemoveUser
      request_type Message::UserCreate
      request_type Message::UserActivate
      # request_type Message::UserRename
      # request_type Message::UserArchive
      # request_type Message::UserSetAdmin
      # request_type Message::UserUnsetAdmin
      # request_type Message::UserChangePassword
      # request_type Message::UserResetPassword
      # request_type Message::UserSearch
      # request_type Message::UserView

      response_type Message::GroupCreated
      response_type Message::GroupUpdated
      response_type Message::GroupDeleted
      response_type Message::GroupList
      response_type Message::GroupInfo
      response_type Message::UserCreated
      response_type Message::UserUpdated
      # response_type Message::UserList
      # response_type Message::UserInfo

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

      def handle_user_create(user, req)
        raise UserNotAllowed, user.login unless user.admin?

        u, token = user_create(
          req.user_login, req.user_name, req.token_lifespan
        )
        args = {
          'user_id' => u.id,
          'activation_token' => token.to_h
        }
        [Message::UserCreated, args]
      end

      def handle_user_activate(user, req)
        raise Error.for_code('AUTH/MISSING') unless req.login_request?

        tk = @store.activation_token_get(user.id)
        raise Error.for_code('AUTH/MISSING') unless tk&.valid?

        user.secret_key(req.password)
        @store.user_activate(user)
        [Message::UserUpdated, { 'user_id' => user.id }]
      end

      # ------- Below are utility methods not directly called from
      # ------- #handle_request

      def group_add_user(group_privk, target_user_id, group)
        target_user = @store.users[target_user_id]
        raise UnknownUser, target_user_id unless target_user

        # Prepare a new keychain item for target user.
        target_keychain_item = Model::KeychainItem.new(
          group_id: group.id, group_pubk: group.pubk,
          privk: group_privk
        )
        # Encrypt group private key for target user.
        target_keychain_item.encrypt(target_user.pubk)
        # Store the damn thing.
        @store.group_add_user(
          group.id, target_user.id, target_keychain_item.encrypted_privk
        )
      end

      def user_create(login, name, token_lifespan)
        u = Model::User.new(
          login:, name:, status: 'new', keychain: {}
        )
        u.id = @store.user_create(u)
        token = Model::ActivationToken.create(u.id, token_lifespan)
        @store.activation_token_create(token)

        [u, token]
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
        encrypted_privk = Crypto.encrypt_group_privk(
          user.pubk, privk
        )
        Log.debug("encrypted_privk = #{encrypted_privk}")
        keychain_item_create(user, group_id, pubk, encrypted_privk)
        Log.info("Group #{name} created with ID #{group_id}")

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
