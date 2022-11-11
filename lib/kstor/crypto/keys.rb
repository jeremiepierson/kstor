# frozen_string_literal: true

require 'kstor/crypto/ascii_armor'

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

    # Wrapper class for an ASCII-armored value.
    class ArmoredValue
      # Create a new ASCII-armored value.
      #
      # @param value [String] ASCII-armored string
      # @return [KStor::Crypto::ArmoredValue] new armored value
      #
      # @see KStor::Crypto::ASCIIArmor#decode
      # @see KStor::Crypto::ASCIIArmor#encode
      def initialize(value)
        @value = value
      end

      # Serialize value.
      #
      # @return [String] serialized value
      def to_ascii
        @value
      end
      alias to_s to_ascii

      # Get back original value.
      #
      # @return [String] binary data
      def to_binary
        ASCIIArmor.decode(@value)
      end

      # Create from binary data
      #
      # @param bin_str [String] binary data
      # @return [KStor::Crypto::ArmoredValue] new value
      def self.from_binary(bin_str)
        new(ASCIIArmor.encode(bin_str))
      end
    end

    # A Hash that can be easily serialized to ASCII chars.
    #
    # Uses JSON as intermediary data format.
    class ArmoredHash < ArmoredValue
      # Create from Ruby Hash.
      #
      # @param hash [Hash] a Ruby Hash.
      # @return [KStor::Crypto::ArmoredHash] new hash
      def self.from_hash(hash)
        from_binary(hash.to_json)
      end

      # Convert to Ruby Hash.
      #
      # @return [Hash] new Ruby Hash
      def to_hash
        JSON.parse(to_binary)
      end

      # Access value for this key.
      #
      # @param key [String] what to lookup
      # @return [Any, nil] value
      def [](key)
        to_hash[key]
      end

      # Set value for a key.
      #
      # @param key [String] hash key
      # @param val [Any] hash value
      def []=(key, val)
        h = to_hash
        h[key] = val
        @value = ASCIIArmor.encode(h.to_json)
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
