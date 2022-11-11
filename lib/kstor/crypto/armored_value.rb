# frozen_string_literal: true

require 'kstor/crypto/ascii_armor'

module KStor
  module Crypto
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
  end
end
