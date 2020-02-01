# frozen_string_literal: true

require 'kstor/crypto'

module KStor
  module Model
    # Base class for model objects.
    class Base
      class << self
        attr_reader :properties
        def property(name)
          @properties ||= []
          @properties << name
          define_method(name) do
            @data[name]
          end
          define_method("#{name}=".to_sym) do |value|
            @data[name] = value
          end
        end

        def property?(name)
          @properties.include?(name)
        end
      end

      def initialize(**values)
        @data = {}
        values.each do |k, v|
          @data[k] = v if self.class.property?(k)
        end
      end
    end

    # A group of users that can access the same set of secrets.
    class Group < Base
      property :id
      property :name
      property :pubk
    end

    # An item in a user keychain: associates a group and it's private key,
    # encrypted with the user's key pair.
    class KeychainItem < Base
      property :group_id
      property :group_pubk
      property :encrypted_privk
      property :privk

      def unlock(group_pubk, user_privk)
        self.privk = Crypto.decrypt_group_privk(
          group_pubk, user_privk, encrypted_privk
        )
      end

      def lock(user_pubk)
        self.encrypted_privk = Crypto.encrypt_group_privk(
          user_pubk, privk, privk
        )
      end
    end

    # A person allowed to connect to the application.
    class User < Base
      property :id
      property :login
      property :name
      property :status
      property :pubk
      property :kdf_params
      property :encrypted_privk
      property :privk
      property :keychain

      def unlock(password)
        secret_key = Crypto.key_derive(password, kdf_params)
        reset_password(password) unless crypto?
        self.privk = Crypto.decrypt_user_privk(secret_key, encrypted_privk)
        keychain.each do |it|
          it.unlock(it.pubk, privk)
        end
      end

      def lock
        self.encrypted_privk = Crypto.encrypt_user_privk(
          secret_key, privk
        )
        keychain.each { |it| it.lock(pubk) }
      end

      def reset_password(password, old_password = nil)
        unless old_password && crypto?
          keypair = Crypto.generate_key_pair
          self.privk = keypair.privk
          self.pubk = keypair.pubk
        end
        secret_key = Crypto.key_derive(password)
        self.kdf_params = secret_key.kdf_params
        lock
      end

      private

      def crypto?
        kdf_params && pubk && encrypted_privk
      end
    end

    # A secret, with metadata and a value that is kepts encrypted on disk.
    class Secret < Base
      property :id
      property :value_author_id
      property :meta_author_id
      property :group_id
      property :ciphertext
      property :encrypted_metadata
      property :metadata

      def unlock(author_pubk, group_privk)
        Crypto.decrypt_secret_value(author_pubk, group_privk, @ciphertext)
      end

      def unlock_metadata(author_pubk, group_privk)
        self.metadata = Crypto.decrypt_secret_metadata(
          author_pubk, group_privk, @encrypted_metadata
        )
      end
    end
  end
end
