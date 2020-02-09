# frozen_string_literal: true

require 'kstor/crypto'

require 'json'

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
        Log.debug("model: unlock user #{login}")
        reset_password(password) unless initialized?
        secret_key = Crypto.key_derive(password, kdf_params)
        self.privk = Crypto.decrypt_user_privk(secret_key, encrypted_privk)
        keychain.values.each { |it| it.unlock(it.group_pubk, privk) }
      end

      def lock(password)
        Log.debug("model: lock user data for #{login}")
        secret_key = Crypto.key_derive(password, kdf_params)
        self.encrypted_privk = Crypto.encrypt_user_privk(
          secret_key, privk
        )
        keychain.values.each { |it| it.lock(pubk) }
      end

      def reset_password(password, old_password = nil)
        Log.info("model: resetting password for user #{login}")
        reset_key_pair unless old_password && initialized?
        secret_key = Crypto.key_derive(password)
        self.kdf_params = secret_key.kdf_params
        lock(password)
      end

      private

      def initialized?
        kdf_params && pubk && encrypted_privk
      end

      def reset_key_pair
        Log.info("model: generating new key pair for user #{login}")
        keypair = Crypto.generate_key_pair
        self.privk = keypair.privk
        self.pubk = keypair.pubk
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
        to_h.to_json
      end

      def self.load(json)
        new(JSON.parse(json))
      end

      def match?(meta)
        to_h.values.zip(meta.to_h.values).all? do |val, wildcard|
          (val.nil? && wildcard.nil?) ||
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

      def metadata=(json)
        @metadata = SecretMeta.load(json)
      end

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
