# frozen_string_literal: true

require 'json'
require 'securerandom'

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
          define_method(name) { @data[name] }
          define_method("#{name}=".to_sym) do |value|
            @data[name] = value
            @dirty = true
          end
          define_method(:dirty?) { @dirty }
          define_method(:clean) { @dirty = false }
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

      def encrypt(user_pubk)
        self.encrypted_privk = Crypto.encrypt_group_privk(
          user_pubk, privk, privk
        )
      end

      def lock
        self.privk = nil
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

      def secret_key(password)
        Log.debug("model: deriving secret key for user #{login}")
        reset_password(password) unless initialized?
        Crypto.key_derive(password, kdf_params)
      end

      def unlock(secret_key)
        Log.debug("model: unlock user #{login}")
        self.privk = Crypto.decrypt_user_privk(secret_key, encrypted_privk)
        keychain.each_value { |it| it.unlock(it.group_pubk, privk) }
      end

      def encrypt(secret_key)
        Log.debug("model: lock user data for #{login}")
        self.encrypted_privk = Crypto.encrypt_user_privk(
          secret_key, privk
        )
        keychain.each_value { |it| it.encrypt(pubk) }
      end

      def lock
        self.privk = nil
        keychain.each_value(&:lock)
      end

      def reset_password(password, old_password = nil)
        Log.info("model: resetting password for user #{login}")
        reset_key_pair unless old_password && initialized?
        secret_key = Crypto.key_derive(password)
        self.kdf_params = secret_key.kdf_params
        encrypt(secret_key)
      end

      def change_password(password, new_password)
        Log.info("model: changing password for user #{login}")
        old_secret_key = secret_key(password)
        unlock(old_secret_key)
        new_secret_key = secret_key(new_password)
        encrypt(new_secret_key)
      end

      private

      def initialized?
        kdf_params && pubk && encrypted_privk
      end

      def reset_key_pair
        Log.info("model: generating new key pair for user #{login}")
        self.pubk, self.privk = Crypto.generate_key_pair
      end
    end

    # Metadata for a secret.
    class SecretMeta
      attr_accessor :app
      attr_accessor :db
      attr_accessor :login
      attr_accessor :server
      attr_accessor :url

      def initialize(**values)
        @app = values['app']
        @db = values['db']
        @login = values['login']
        @server = values['server']
        @url = values['url']
      end

      def to_h
        { 'app' => @app, 'db' => @db, 'login' => @login,
          'server' => @server, 'url' => @url }
      end

      def serialize
        Crypto::ArmoredHash.from_hash(to_h)
      end

      def self.load(armored_hash)
        new(**armored_hash.to_hash)
      end

      def match?(meta)
        to_h.values.zip(meta.to_h.values).all? do |val, wildcard|
          (val.nil? || wildcard.nil?) ||
            File.fnmatch?(
              wildcard, val, File::FNM_CASEFOLD | File::FNM_DOTMATCH
            )
        end
      end
    end

    # A secret, with metadata and a value that are kept encrypted on disk.
    class Secret < Base
      property :id
      property :value_author_id
      property :meta_author_id
      property :group_id
      property :ciphertext
      property :encrypted_metadata

      attr_reader :metadata

      # FIXME! use Crypto::ArmoredHash
      def metadata=(armored_hash)
        @metadata = SecretMeta.load(armored_hash)
      end

      def unlock(author_pubk, group_privk)
        Crypto.decrypt_secret_value(author_pubk, group_privk, ciphertext)
      end

      def unlock_metadata(author_pubk, group_privk)
        Log.debug("model: secret data = #{@data.inspect}")
        self.metadata = Crypto.decrypt_secret_metadata(
          author_pubk, group_privk, encrypted_metadata
        )
      end
    end
  end
end
