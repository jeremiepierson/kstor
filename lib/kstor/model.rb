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

        def property(name, read_only: false)
          @properties ||= []
          @properties << name
          define_method(name) do
            @data[name]
          end
          return if read_only

          define_method("#{name}=".to_sym) do |value|
            @data[name] = value
            @dirty = true
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
        @dirty = false
      end

      def dirty?
        @dirty
      end

      def clean
        @dirty = false
      end

      def to_h
        @data.to_h { |k, v| [k.to_s, v.respond_to?(:to_h) ? v.to_h : v] }
      end
    end

    # A group of users that can access the same set of secrets.
    class Group < Base
      property :id
      property :name
      property :pubk

      def to_h
        h = super
        h.delete('pubk')

        h
      end
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

      def locked?
        privk.nil?
      end

      def unlocked?
        !locked?
      end

      def to_h
        h = super
        h.delete('encrypted_privk')
        h
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
        return if unlocked?

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
        return if locked?

        self.privk = nil
        keychain.each_value(&:lock)
      end

      def locked?
        privk.nil? && keychain.all? { |_, it| it.locked? }
      end

      def unlocked?
        !privk.nil? || keychain.any? { |_, it| it.unlocked? }
      end

      def reset_password(password, old_password = nil)
        Log.info("model: resetting password for user #{login}")
        if old_password && initialized?
          old_secret_key = secret_key(old_password)
          unlock(old_secret_key)
        else
          reset_key_pair
        end
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

      def to_h
        h = super
        h.delete('encrypted_privk')
        h.delete('pubk')
        h['keychain'] = keychain.transform_values(&:to_h) if keychain

        h
      end

      private

      def initialized?
        kdf_params && pubk && encrypted_privk
      end

      def reset_key_pair
        Log.info("model: generating new key pair for user #{login}")
        self.pubk, self.privk = Crypto.generate_key_pair
        self.keychain = {}
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
          'server' => @server, 'url' => @url }.compact
      end

      def serialize
        Crypto::ArmoredHash.from_hash(to_h)
      end

      def self.load(armored_hash)
        new(**armored_hash.to_hash)
      end

      def match?(meta)
        self_h = to_h
        other_h = meta.to_h
        other_h.each do |k, wildcard|
          val = self_h[k]
          next if val.nil?
          next if wildcard.nil?

          key_matched = File.fnmatch?(
            wildcard, val, File::FNM_CASEFOLD | File::FNM_DOTMATCH
          )
          return false unless key_matched
        end
        true
      end
    end

    # A secret, with metadata and a value that are kept encrypted on disk.
    class Secret < Base
      property :id
      property :value_author_id
      property :meta_author_id
      property :group_id
      property :ciphertext
      property :plaintext
      property :encrypted_metadata
      property :metadata, read_only: true

      def metadata=(armored_hash)
        @data[:metadata] = armored_hash ? SecretMeta.load(armored_hash) : nil
      end

      def unlock(author_pubk, group_privk)
        self.plaintext = Crypto.decrypt_secret_value(
          author_pubk, group_privk, ciphertext
        )
      end

      def unlock_metadata(author_pubk, group_privk)
        self.metadata = Crypto.decrypt_secret_metadata(
          author_pubk, group_privk, encrypted_metadata
        )
      end

      def lock
        self.metadata = nil
        self.plaintext = nil
      end

      def to_h
        h = super
        h.delete('ciphertext')
        h.delete('encrypted_metadata')
        h.delete('value_author_id')
        h.delete('meta_author_id')

        h
      end
    end
  end
end
