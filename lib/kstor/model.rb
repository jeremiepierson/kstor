# frozen_string_literal: true

require 'json'
require 'securerandom'

require 'kstor/crypto'

module KStor
  module Model
    # @!macro [new] dsl_model_properties_rw
    #   @!attribute $1
    #     @return returns value of property $1

    # Base class for model objects.
    class Base
      class << self
        attr_reader :properties

        # Define a named property
        #
        # @param name [Symbol] name of the property
        # @param read_only [Boolean] false to define both a getter and a setter
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

        # Check if a property is defined.
        #
        # @param name [Symbol] name of the property
        # @return [Boolean] true if it is defined
        def property?(name)
          @properties.include?(name)
        end
      end

      # Create a model object from hash values
      #
      # @param values [Hash] property values
      # @return [KStor::Model::Base] a new model object
      def initialize(**values)
        @data = {}
        values.each do |k, v|
          @data[k] = v if self.class.property?(k)
        end
        @dirty = false
      end

      # Check if properties were modified since instanciation
      #
      # @return [Boolean] true if modified
      def dirty?
        @dirty
      end

      # Tell the object that dirty properties were persisted.
      def clean
        @dirty = false
      end

      # Represent model object as a Hash
      #
      # @return [Hash] a hash of model object properties
      def to_h
        @data.to_h { |k, v| [k.to_s, v.respond_to?(:to_h) ? v.to_h : v] }
      end
    end

    # A group of users that can access the same set of secrets.
    class Group < Base
      # @!macro dsl_model_properties_rw
      property :id
      # @!macro dsl_model_properties_rw
      property :name
      # @!macro dsl_model_properties_rw
      property :pubk

      # Dump properties except pubk.
      def to_h
        super.except('pubk')
      end
    end

    # An item in a user keychain: associates a group and it's private key,
    # encrypted with the user's key pair.
    #
    # Initially encrypted, the {#privk} property will be nil until {#unlock}ed.
    class KeychainItem < Base
      # @!macro dsl_model_properties_rw
      property :group_id
      # @!macro dsl_model_properties_rw
      property :group_pubk
      # @!macro dsl_model_properties_rw
      property :encrypted_privk
      # @!macro dsl_model_properties_rw
      property :privk

      # Decrypt group private key.
      #
      # Calling this method will set the {#privk} property.
      #
      # @param group_pubk [PublicKey] public key to verify ciphertext signature
      # @param user_privk [PrivateKey] private key of owner of keychain item
      def unlock(group_pubk, user_privk)
        self.privk = Crypto.decrypt_group_privk(
          group_pubk, user_privk, encrypted_privk
        )
      end

      # Re-encrypt group private key.
      #
      # Calling this will overwrite the {#encrypted_privk} property.
      #
      # @param user_pubk [KStor::Crypto::PublicKey] public key of keychain item
      #   owner
      def encrypt(user_pubk)
        self.encrypted_privk = Crypto.encrypt_group_privk(
          user_pubk, privk, privk
        )
      end

      # Forget about decrypted group private key.
      #
      # This will unset {#privk} property.
      def lock
        self.privk = nil
      end

      # Check if group private key was decrypted.
      #
      # @return [Boolean] false if decrypted
      def locked?
        privk.nil?
      end

      # Check if group private key was decrypted.
      #
      # @return [Boolean] true if decrypted
      def unlocked?
        !locked?
      end

      # Dump properties except {#encrypted_privk}.
      def to_h
        super.except('encrypted_privk')
      end
    end

    # A person allowed to connect to the application.
    class User < Base
      # @!macro dsl_model_properties_rw
      property :id
      # @!macro dsl_model_properties_rw
      property :login
      # @!macro dsl_model_properties_rw
      property :name
      # @!macro dsl_model_properties_rw
      property :status
      # @!macro dsl_model_properties_rw
      property :pubk
      # @!macro dsl_model_properties_rw
      property :kdf_params
      # @!macro dsl_model_properties_rw
      property :encrypted_privk
      # @!macro dsl_model_properties_rw
      property :privk
      # @!macro dsl_model_properties_rw
      property :keychain

      # Derive secret key from password.
      #
      # If user has no keypair yet, initialize it.
      #
      # @param password [String] plaintext password
      # @return [KStor::Crypto::SecretKey] derived secret key
      def secret_key(password)
        Log.debug("model: deriving secret key for user #{login}")
        reset_password(password) unless initialized?
        Crypto.key_derive(password, kdf_params)
      end

      # Decrypt user private key and keychain.
      #
      # This will set the {#privk} property and call {KeychainItem#unlock} on
      # the keychain.
      #
      # @param secret_key [KStor::Crypto::SecretKey] secret key derived from
      #   password
      # @see #secret_key
      def unlock(secret_key)
        return if unlocked?

        Log.debug("model: unlock user #{login}")
        self.privk = Crypto.decrypt_user_privk(secret_key, encrypted_privk)
        keychain.each_value { |it| it.unlock(it.group_pubk, privk) }
      end

      # Re-encrypt user private key and keychain.
      #
      # This will overwrite the {#encrypted_privk} property and call
      # {KeychainItem#encrypt} on the keychain.
      #
      # @param secret_key [KStor::Crypto::SecretKey] secret key derived from
      #   password
      # @see #secret_key
      def encrypt(secret_key)
        Log.debug("model: lock user data for #{login}")
        self.encrypted_privk = Crypto.encrypt_user_privk(
          secret_key, privk
        )
        keychain.each_value { |it| it.encrypt(pubk) }
      end

      # Forget about the user's decrypted private key and the group private
      # keys in the keychain.
      #
      # This will unset the {#privk} property and call {KeychainItem#lock} on
      # the keychain.
      def lock
        return if locked?

        self.privk = nil
        keychain.each_value(&:lock)
      end

      # Check if some sensitive data was decrypted.
      #
      # @return [Boolean] true if private key or keychain was decrypted
      def locked?
        privk.nil? && keychain.all? { |_, it| it.locked? }
      end

      # Check if no sensitive data was decrypted.
      #
      # @return [Boolean] true if neither private key nor any keychain iyem was
      #   decrypted.
      def unlocked?
        !privk.nil? || keychain.any? { |_, it| it.unlocked? }
      end

      # Generate a new key pair and throw away all keychain
      # items.
      #
      # @param password [String] new user password
      def reset_password(password)
        Log.info("model: resetting password for user #{login}")
        reset_key_pair
        secret_key = Crypto.key_derive(password)
        self.kdf_params = secret_key.kdf_params
        encrypt(secret_key)
        self.keychain = {}
      end

      # Re-encrypt private key and keychain with a new secret key derived from
      # the new password.
      #
      # @param password [String] old password
      # @param new_password [String] new password
      def change_password(password, new_password)
        Log.info("model: changing password for user #{login}")
        old_secret_key = secret_key(password)
        unlock(old_secret_key)
        new_secret_key = secret_key(new_password)
        encrypt(new_secret_key)
      end

      # Dump properties except {#encrypted_privk} and {#pubk}.
      def to_h
        h = super.except('encrypted_privk', 'pubk')
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
    #
    # This is not a "real" model object: just a helper class to convert
    # metadata to and from database.
    class SecretMeta
      # Secret is defined for this application
      attr_accessor :app
      # Secret is defined for this database
      attr_accessor :database
      # Secret is defined for this login
      attr_accessor :login
      # Secret is related to this server
      attr_accessor :server
      # Secret should be used at this URL
      attr_accessor :url

      # Create new metadata for a secret.
      #
      # Hash param can contains keys for "app", "database", "login", "server"
      # and "url". Any other key is ignored.
      #
      # @param values [Hash[String, String]] metadata
      # @return [KStor::Model::SecretMeta] secret metadata
      def initialize(values)
        @app = values['app']
        @database = values['database']
        @login = values['login']
        @server = values['server']
        @url = values['url']
      end

      # Convert this metadata to a Hash.
      #
      # Empty values will not be included.
      #
      # @return [Hash[String, String]] metadata as a Hash
      def to_h
        { 'app' => @app, 'database' => @database, 'login' => @login,
          'server' => @server, 'url' => @url }.compact
      end

      # Prepare metadata to be written to disk or database.
      #
      # @return [KStor::Crypto::ArmoredHash] serialized metadata
      def serialize
        Crypto::ArmoredHash.from_hash(to_h)
      end

      # Merge metadata.
      #
      # @param other [KStor::Model::SecretMeta] other metadata that will
      #   override this object's values.
      def merge(other)
        values = to_h.merge(other.to_h)
        values.reject! { |_, v| v.empty? }
        self.class.new(values)
      end

      # Unserialize metadata.
      #
      # FIXME: probably useless as ArmoredHash already behaves like a Hash;
      #        just use .new().
      #
      # @param armored_hash [KStor::Crypto::ArmoredHash] serialized metadata
      def self.load(armored_hash)
        new(armored_hash.to_hash)
      end

      # Match against wildcards.
      #
      # Metadata will be matched against another metadata object with wildcard
      # values. This uses roughly the same rules that shell wildcards (e.g.
      # fnmatch(3) C function).
      #
      # @see File.fnmatch?
      #
      # @param meta [KStor::Model::SecretMeta] wildcard metadata
      # @return [Boolean] true if matched
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
      # @!macro dsl_model_properties_rw
      property :id
      # @!macro dsl_model_properties_rw
      property :value_author_id
      # @!macro dsl_model_properties_rw
      property :meta_author_id
      # @!macro dsl_model_properties_rw
      property :group_id
      # @!macro dsl_model_properties_rw
      property :ciphertext
      # @!macro dsl_model_properties_rw
      property :plaintext
      # @!macro dsl_model_properties_rw
      property :encrypted_metadata
      # @!macro dsl_model_properties_rw
      property :metadata, read_only: true

      # Set metadata (or unset if nil).
      #
      # @param armored_hash [KStor::Crypt::ArmoredHash] metadata to load
      def metadata=(armored_hash)
        @data[:metadata] = armored_hash ? SecretMeta.load(armored_hash) : nil
      end

      # Decrypt secret value.
      #
      # This will set the {#plaintext} property.
      #
      # @param author_pubk [KStor::Crypto::PublicKey] key to verify signature
      #   by the user that last set the value
      # @param group_privk [KStor::Crypto::PrivateKey] private key of a group
      #   that can decrypt this secret value.
      def unlock(author_pubk, group_privk)
        self.plaintext = Crypto.decrypt_secret_value(
          author_pubk, group_privk, ciphertext
        )
      end

      # Decrypt secret metadata.
      #
      # This will set the {#metadata} property.
      #
      # @param author_pubk [KStor::Crypto::PublicKey] key to verify signature
      #   by the user that last set metadata
      # @param group_privk [KStor::Crypto::PrivateKey] private key of a group
      #   that can decrypt this secret metadata.
      def unlock_metadata(author_pubk, group_privk)
        self.metadata = Crypto.decrypt_secret_metadata(
          author_pubk, group_privk, encrypted_metadata
        )
      end

      # Forget about the decrypted value and metadata.
      def lock
        self.metadata = nil
        self.plaintext = nil
      end

      # Dump properties except {#ciphertext}, {#encrypted_metadata},
      # {#value_author_id} and {#meta_author_id}.
      def to_h
        super.except(
          *%w[ciphertext encrypted_metadata value_author_id meta_author_id]
        )
      end
    end
  end
end
