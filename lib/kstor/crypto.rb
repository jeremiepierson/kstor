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
      # @param params_str [String, nil] KDF parameters encoded as an opaque
      #   string; if nil, use defaults.
      # @return [SecretKey] secret key and KDF parameters encoded as an opaque
      #   string
      def key_derive(passphrase, params_str = nil)
        params = key_derive_params_unserialize(params_str)
        Log.debug("crypto: kdf params = #{params.inspect}")
        data = RbNaCl::PasswordHash.argon2(
          passphrase, params['salt'],
          params['opslimit'], params['memlimit'], params['digest_size']
        )
        SecretKey.new(b2a(data), key_derive_params_serialize(params))
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
      def kdf_params_obsolete?(params_str)
        return true if params_str.nil?

        key_derive_params_unserialize(params_str)['_version'] != VERSION
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      def generate_key_pair
        privk = RbNaCl::PrivateKey.generate
        pubk = privk.public_key
        KeyPair.new(b2a(pubk.to_bytes), b2a(privk.to_bytes))
      end

      def encrypt_user_privk(secret_key, privk)
        box_secret_encrypt(secret_key, a2privk(privk))
      end

      def decrypt_user_privk(secret_key, privk)
        privk2a(RbNaCl::PrivateKey.new(box_secret_decrypt(secret_key, privk)))
      end

      def encrypt_group_privk(user_pubk, group_privk)
        box_pair_encrypt(user_pubk, group_privk, group_privk)
      end

      def decrypt_group_privk(group_pubk, user_privk, group_privk)
        b2a(box_pair_decrypt(group_pubk, user_privk, group_privk))
      end

      def encrypt_secret_value(group_pubk, user_privk, value)
        box_pair_encrypt(group_pubk, user_privk, value)
      end

      def decrypt_secret_value(user_pubk, group_privk, str)
        box_pair_decrypt(user_pubk, group_privk, str)
      end

      def encrypt_secret_metadata(group_pubk, user_privk, metadata_as_hash)
        json = metadata_as_hash.to_json
        encrypt_secret_value(group_pubk, user_privk, json)
      end

      def decrypt_secret_metadata(user_pubk, group_privk, str)
        json = decrypt_secret_value(user_pubk, group_privk, str)
        JSON.parse(json)
      end

      private

      # Encrypt raw data with a secret key.
      #
      # @param secret_key [String] secret key as ASCII-armored string
      # @param bytes [String] raw data to encrypt
      # @return [String] ASCII-armored ciphertext
      def box_secret_encrypt(secret_key, bytes)
        ciphertext = make_secret_box(secret_key).encrypt(bytes)
        b2a(ciphertext)
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Decrypt data with a secret key.
      #
      # @param secret_key [String] secret key as ASCII-armored string
      # @param str [String] ASCII-armored ciphertext to decrypt
      # @return [String] raw decrypted plaintext
      def box_secret_decrypt(secret_key, str)
        make_secret_box(secret_key).decrypt(a2b(str))
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Encrypt and authenticate data with public-key crypto.
      #
      # @param pubk [String] ASCII-armored public key
      # @param privk [String] ASCII-armored private key
      # @param bytes [String] raw data to encrypt
      # @return [String] ASCII-armored ciphertext
      def box_pair_encrypt(pubk, privk, bytes)
        b2a(make_pair_box(pubk, privk).encrypt(bytes))
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Decrypt and authentify data with public-key crypto.
      #
      # @param pubk [String] ASCII-armored public key
      # @param privk [String] ASCII-armored private key
      # @param str [String] ASCII-armored ciphertext to decrypt
      # @return [String] raw decrypted plaintext
      def box_pair_decrypt(pubk, privk, str)
        make_pair_box(pubk, privk).decrypt(a2b(str))
      rescue RbNaCl::CryptoError => e
        raise Error.for_code('CRYPTO/RBNACL', e.message)
      end

      # Make a SimpleBox for symetric crypto.
      #
      # @param secret_key [String] ASCII-armored secret key
      # @return [RbNaCl::SimpleBox] the box
      def make_secret_box(secret_key)
        RbNaCl::SimpleBox.from_secret_key(a2b(secret_key.value))
      end

      # Make a SimpleBox for asymetric cypto.
      #
      # @param pubk [String] ASCII-armored public key
      # @param privk [String] ASCII-armored private key
      # @return [RbNaCl::SimpleBox] the box
      def make_pair_box(pubk, privk)
        RbNaCl::SimpleBox.from_keypair(a2pubk(pubk), a2privk(privk))
      end

      # Decode ASCII-armored KDF parameters.
      #
      # @param str [Nil, String] ASCII-armored parameters or nil
      # @return [Hash<String, Object>] decoded or newly generated KDF
      #   parameters.
      def key_derive_params_unserialize(str = nil)
        return key_derive_params_generate unless str

        h = JSON.parse(str)
        h['salt'] = a2b(h['salt'])
        h['opslimit'] = h['opslimit'].to_sym
        h['memlimit'] = h['memlimit'].to_sym
        h
      end

      # ASCII-armor KDF parameters.
      #
      # @param params [Hash<String, Object>] KDF parameters
      # @return [String] ASCII-armored KDF parameters
      def key_derive_params_serialize(params)
        params['salt'] = b2a(params['salt'])
        params.to_json
      end

      # Generate new parameters for the Key Derivation Function.
      #
      # @return [Hash<String, Object>] newly generated KDF parameters
      def key_derive_params_generate
        salt = RbNaCl::Random.random_bytes(
          RbNaCl::PasswordHash::Argon2::SALTBYTES
        )
        { '_version' => VERSION, 'salt' => salt,
          'opslimit' => :moderate, 'memlimit' => :moderate,
          'digest_size' => RbNaCl::SecretBox.key_bytes }
      end
    end
  end
end
