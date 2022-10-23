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
      # @param [String] kdf_param ASCII-armored key derivation parameters
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
      def initialize(value)
        @value = value
      end

      def to_ascii
        @value
      end
      alias to_s to_ascii

      def to_binary
        ASCIIArmor.decode(@value)
      end

      def self.from_binary(bin_str)
        new(ASCIIArmor.encode(bin_str.to_str))
      end
    end

    # A Hash.
    class ArmoredHash < ArmoredValue
      def self.from_hash(hash)
        from_binary(ASCIIArmor.encode(hash.to_json))
      end

      def to_hash
        JSON.parse(to_binary)
      end

      def [](key)
        to_hash[key]
      end

      def []=(key, val)
        h = to_hash
        h[key] = val
        @value = ASCIIArmor.encode(h.to_json)
      end
    end

    # KDF parameters.
    class KDFParams < ArmoredHash
      def self.from_hash(hash)
        hash['salt'] = ASCIIArmor.encode(hash['salt'])
        hash['opslimit'] = h['opslimit'].to_s
        hash['memlimit'] = h['memlimit'].to_s
        super(hash)
      end

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
      def to_rbnacl
        RbNaCl::PrivateKey.new(to_binary)
      end
    end

    # A public key.
    class PublicKey < ArmoredValue
      def to_rbnacl
        RbNaCl::PublicKey.new(to_binary)
      end
    end
  end
end
