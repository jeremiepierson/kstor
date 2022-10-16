# frozen_string_literal: true

require 'kstor/store'
require 'kstor/model'
require 'kstor/crypto'
require 'kstor/log'

module KStor
  # Handle user and group related requests.
  module UserController
    def group_create(name)
      pubk, privk = Crypto.generate_key_pair
      group_id = @store.group_create(name, pubk)
      encrypted_privk = Crypto.encrypt_group_privk(
        @user.pubk, privk
      )
      Log.debug("encrypted_privk = #{encrypted_privk}")
      keychain_item_create(group_id, pubk, encrypted_privk)

      Model::Group.new(id: group_id, name: name, pubk: pubk)
    end

    private

    def keychain_item_create(group_id, pubk, encrypted_privk)
      item = Model::KeychainItem.new(
        group_id: group_id,
        group_pubk: pubk,
        encrypted_privk: encrypted_privk
      )
      @user.keychain[item.group_id] = item
      @store.keychain_item_create(@user.id, group_id, encrypted_privk)
    end
  end
end
