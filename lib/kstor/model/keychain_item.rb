# frozen_string_literal: true

module KStor
  module Model
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
          user_pubk, privk
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
  end
end
