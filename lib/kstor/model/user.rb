# frozen_string_literal: true

module KStor
  module Model
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

      # True if user is an administrator.
      def admin?
        status == 'admin'
      end

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
  end
end
