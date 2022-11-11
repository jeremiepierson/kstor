# frozen_string_literal: true

require 'kstor/crypto/ascii_armor'
require 'kstor/crypto/armored_value'

module KStor
  module Crypto
    # Holds together a secret key value and the KDF associated parameters.
    class SecretKey
      # The secret key as an ASCII-armored String
      attr_reader :value
      # KDF parameters as an ASCII-armored String
      attr_reader :kdf_params

      # Create a SecretKey instance.
      #
      # @param [String] value ASCII-armored secret key derived from passphrase
      # @param [String] kdf_params ASCII-armored key derivation parameters
      # @return [SecretKey] the SecretKey object
      def initialize(value, kdf_params)
        @value = value
        @kdf_params = kdf_params
      end
    end

    # Holds together a public and private key pair.
    class KeyPair
      # ASCII-armored public key
      attr_reader :pubk
      # ASCII-armored private key
      attr_reader :privk

      # Create a KeyPair instance.
      #
      # @param [String] pubk ASCII-armored public key
      # @param [String] privk ASCII-armored private key
      def initialize(pubk, privk)
        @pubk = pubk
        @privk = privk
      end
    end

    # KDF parameters.
    class KDFParams < ArmoredHash
      # Create new Key Derivation Function parameters from a Ruby Hash.
      #
      # Hash parameter must have keys for "salt"," opslimit" and "memlimit".
      #
      # @param hash [Hash] KDF parameters data.
      def self.from_hash(hash)
        hash['salt'] = ASCIIArmor.encode(hash['salt'])
        hash['opslimit'] = hash['opslimit'].to_s
        hash['memlimit'] = hash['memlimit'].to_s
        super(hash)
      end

      # Convert back to a Ruby Hash.
      def to_hash
        hash = super
        hash['salt'] = ASCIIArmor.decode(hash['salt'])
        hash['opslimit'] = hash['opslimit'].to_sym
        hash['memlimit'] = hash['memlimit'].to_sym

        hash
      end
    end

    # A private key.
    class PrivateKey < ArmoredValue
      # Convert ASCII-armored value to a RbNaCl private key.
      def to_rbnacl
        RbNaCl::PrivateKey.new(to_binary)
      end
    end

    # A public key.
    class PublicKey < ArmoredValue
      # Convert ASCII-armored value to a RbNaCl public key.
      def to_rbnacl
        RbNaCl::PublicKey.new(to_binary)
      end
    end
  end
end
