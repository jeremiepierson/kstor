# frozen_string_literal: true

module KStor
  module Model
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
        @data[:metadata] = armored_hash ? SecretMeta.new(armored_hash) : nil
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
