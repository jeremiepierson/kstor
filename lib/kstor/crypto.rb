# frozen_string_literal: true

require 'rbnacl'
require 'json'
require 'base64'

require 'kstor/error'
require 'kstor/crypto/ascii_armor'
require 'kstor/crypto/keys'

module KStor
  # Generic crypto error.
  class CryptoError < Error
    error_code 'CRYPTO/UNSPECIFIED'
    error_message 'Cryptographic error.'
  end

  # Error in key derivation.
  class RbNaClError < Error
    error_code 'CRYPTO/RBNACL'
    error_message 'RbNaCl error: %s'
  end

  # Cryptographic functions for KStor.
  #
  # @version 1.0
  module Crypto
    VERSION = 1

    class << self
      # Derive a secret key suitable for symetric encryption from a passphrase.
      #
      # Key derivation function can use previously stored parameters (as an
      # opaque String) or pass nil to generate random parameters.
      #
      # @param passphrase [String] user passphrase as clear text
      # @param params_str [KDFParams, nil] KDF parameters string;
      #   if nil, use defaults.
      # @return [SecretKey] secret key and KDF parameters
      def key_derive(passphrase, params = nil)
        params ||= key_derive_params_generate
        Log.debug("crypto: kdf params = #{params.to_hash}")
        data = RbNaCl::PasswordHash.argon2(
          passphrase, params['salt'],
          params['opslimit'], params['memlimit'], params['digest_size']
        )
        SecretKey.new(ArmoredValue.from_binary(data), params)
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Check if KDF params match current code in this library.
      #
      # If it is obsolete, you should generate a new secret key from the user's
      # passphrase, and re-encrypt everything that was encrypted with the old
      # secret key.
      #
      # @param params_str [String] KDF params as an opaque string.
      # @return [Boolean] false if parameters match current library version.
      def kdf_params_obsolete?(params)
        return true if params_str.nil?

        params['_version'] != VERSION
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Generate new key pair.
      #
      # @return [Array<PublicKey, PrivateKey>] new key pair
      def generate_key_pair
        privk = RbNaCl::PrivateKey.generate
        pubk = privk.public_key
        [PublicKey.from_binary(pubk.to_bytes),
         PrivateKey.from_binary(privk.to_bytes)]
      end

      # Encrypt user private key.
      #
      # @param [SecretKey] secret_key secret key derived from passphrase
      # @param [PrivateKey] privk private key
      # @return [ArmoredValue] encrypted user private key
      def encrypt_user_privk(secret_key, privk)
        box_secret_encrypt(secret_key, privk.to_binary)
      end

      # Decrypt user private key.
      #
      # @param [SecretKey] secret_key secret key derived from passphrase
      # @param [ArmoredValue] ciphertext encrypted private key
      # @return [PrivateKey] user private key
      def decrypt_user_privk(secret_key, ciphertext)
        privk_data = box_secret_decrypt(secret_key, ciphertext)
        PrivateKey.from_binary(privk_data)
      end

      # Encrypt and sign group private key.
      #
      # @param [PublicKey] owner_pubk user public key
      # @param [PrivateKey] group_privk group private key
      # @return [ArmoredValue] encrypted group private key
      def encrypt_group_privk(owner_pubk, group_privk)
        box_pair_encrypt(owner_pubk, group_privk, group_privk.to_binary)
      end

      # Decrypt and verify group private key.
      #
      # @param [PublicKey] group_pubk group public key to verify signature
      # @param [PrivateKey] owner_privk user private key
      # @param [ArmoredValue] encrypted_group_privk encrypted group private key
      # @return [PrivateKey] group private key
      def decrypt_group_privk(group_pubk, owner_privk, encrypted_group_privk)
        PrivateKey.from_binary(
          box_pair_decrypt(group_pubk, owner_privk, encrypted_group_privk)
        )
      end

      # Encrypt and sign secret value.
      #
      # @param [PublicKey] group_pubk group public key
      # @param [PrivateKey] author_privk user private key
      # @param [String] value secret value
      # @return [ArmoredValue] ASCII-armored encrypted secret value
      def encrypt_secret_value(group_pubk, author_privk, value)
        box_pair_encrypt(group_pubk, author_privk, value)
      end

      # Decrypt and verify secret value.
      #
      # @param [PublicKey] author_pubk user secret key
      # @param [PrivateKey] group_privk group private key
      # @param [ArmoredValue] val encrypted secret value
      # @return [String] original secret value
      def decrypt_secret_value(author_pubk, group_privk, val)
        box_pair_decrypt(author_pubk, group_privk, val)
      end

      # Encrypt and sign secret metadata.
      #
      # @param [PublicKey] group_pubk group public key
      # @param [PrivateKey] author_privk user private key
      # @param [Hash] metadata_as_hash Hash of keys and values
      # @return [ArmoredValue] encrypted secret metadata
      def encrypt_secret_metadata(group_pubk, author_privk, metadata_as_hash)
        meta = ArmoredHash.from_hash(metadata_as_hash)
        encrypt_secret_value(group_pubk, author_privk, meta.to_binary)
      end

      # Decrypt and verify secret metadata.
      #
      # @param [PublicKey] author_pubk user public key
      # @param [PrivateKey] group_privk group private key
      # @param [ArmoredValue] val encrypted secret metadata
      # @return [Hash] Hash of keys and values
      def decrypt_secret_metadata(author_pubk, group_privk, val)
        bytes = decrypt_secret_value(author_pubk, group_privk, val)
        ArmoredHash.from_binary(bytes).to_hash
      end

      private

      # Encrypt raw data with a secret key.
      #
      # @param [SecretKey] secret_key secret key
      # @param [String] bytes raw data to encrypt
      # @return [ArmoredValue] ciphertext
      def box_secret_encrypt(secret_key, bytes)
        ciphertext = make_secret_box(secret_key).encrypt(bytes)
        ArmoredValue.from_binary(ciphertext)
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Decrypt data with a secret key.
      #
      # @param [SecretKey] secret_key secret key
      # @param [ArmoredValue] val ciphertext to decrypt
      # @return [String] raw decrypted plaintext
      def box_secret_decrypt(secret_key, val)
        make_secret_box(secret_key).decrypt(val.to_binary)
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Encrypt and authenticate data with public-key crypto.
      #
      # @param [PublicKey] pubk public key
      # @param [PrivateKey] privk private key
      # @param [String] bytes raw data to encrypt
      # @return [ArmoredValue] ciphertext
      def box_pair_encrypt(pubk, privk, bytes)
        ArmoredValue.from_binary(make_pair_box(pubk, privk).encrypt(bytes))
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Decrypt and authentify data with public-key crypto.
      #
      # @param [PublicKey] pubk public key
      # @param [PrivateKey] privk private key
      # @param [ArmoredValue] val ciphertext to decrypt
      # @return [String] raw decrypted plaintext
      def box_pair_decrypt(pubk, privk, val)
        make_pair_box(pubk, privk).decrypt(val.to_binary)
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Make a SimpleBox for symetric crypto.
      #
      # @param secret_key [SecretKey] secret_key secret key
      # @return [RbNaCl::SimpleBox] the box
      def make_secret_box(secret_key)
        RbNaCl::SimpleBox.from_secret_key(secret_key.value.to_binary)
      end

      # Make a SimpleBox for asymetric cypto.
      #
      # @param [PublicKey] pubk public key
      # @param [PrivateKey] privk private key
      # @return [RbNaCl::SimpleBox] the box
      def make_pair_box(pubk, privk)
        RbNaCl::SimpleBox.from_keypair(pubk.to_binary, privk.to_binary)
      end

      # Generate new parameters for the Key Derivation Function.
      #
      # @return [KDFParams] newly generated KDF parameters
      def key_derive_params_generate
        salt = RbNaCl::Random.random_bytes(
          RbNaCl::PasswordHash::Argon2::SALTBYTES
        )
        h = { '_version' => VERSION, 'salt' => salt,
              'opslimit' => :moderate, 'memlimit' => :moderate,
              'digest_size' => RbNaCl::SecretBox.key_bytes }
        KDFParams.from_hash(h)
      end
    end
  end
end
